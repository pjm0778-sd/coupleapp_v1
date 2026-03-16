import * as XLSX from 'npm:xlsx@0.18.5'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

type ScheduleItem = {
  start_date: string
  end_date: string
  work_type: string
  color_hex: string
}

function getColorForWorkType(workType: string): string {
  const t = workType.toLowerCase().trim()
  if (/주간|^d$|day|낮|오전/.test(t)) return '#4CAF50'
  if (/야간|^n$|night|밤|심야/.test(t)) return '#3F51B5'
  if (/저녁|^e$|evening|오후|pm/.test(t)) return '#FF9800'
  if (/휴무|오프|^o$|off|공휴일|휴가|비번/.test(t)) return '#9E9E9E'
  if (/당직|비상/.test(t)) return '#9C27B0'
  return '#607D8B'
}

function extractSchedulesForName(
  rows: unknown[][],
  name: string,
  targetYear: number,
  targetMonth: number,
): ScheduleItem[] {
  // Find the row that contains the target name
  let nameRowIndex = -1
  let nameColIndex = -1

  for (let r = 0; r < rows.length; r++) {
    for (let c = 0; c < rows[r].length; c++) {
      const cell = String(rows[r][c] ?? '').trim()
      if (cell.includes(name)) {
        nameRowIndex = r
        nameColIndex = c
        break
      }
    }
    if (nameRowIndex !== -1) break
  }

  if (nameRowIndex === -1) return []

  // Find date header row: a row with >= 7 numeric values between 1-31
  let dateRowIndex = -1
  for (let r = 0; r < nameRowIndex; r++) {
    const numCount = rows[r].filter((cell) => {
      const n = Number(cell)
      return Number.isInteger(n) && n >= 1 && n <= 31
    }).length
    if (numCount >= 7) {
      dateRowIndex = r
      break
    }
  }

  // Fallback: look for "N일" pattern
  if (dateRowIndex === -1) {
    for (let r = 0; r < nameRowIndex; r++) {
      const dateCount = rows[r].filter((cell) =>
        /^\d{1,2}일?$/.test(String(cell ?? '').trim()),
      ).length
      if (dateCount >= 7) {
        dateRowIndex = r
        break
      }
    }
  }

  if (dateRowIndex === -1) return []

  const dateRow = rows[dateRowIndex]
  const nameRow = rows[nameRowIndex]
  const schedules: ScheduleItem[] = []

  for (let c = 0; c < dateRow.length; c++) {
    if (c === nameColIndex) continue

    const dateCell = String(dateRow[c] ?? '').trim()
    const dayNum = parseInt(dateCell.replace('일', ''))
    if (isNaN(dayNum) || dayNum < 1 || dayNum > 31) continue

    const workCell = String(nameRow[c] ?? '').trim()
    if (!workCell || workCell === '-' || workCell === '0') continue

    // Validate date
    const dateObj = new Date(targetYear, targetMonth - 1, dayNum)
    if (dateObj.getMonth() !== targetMonth - 1) continue // overflow date

    const dateStr = `${targetYear}-${String(targetMonth).padStart(2, '0')}-${String(dayNum).padStart(2, '0')}`

    schedules.push({
      start_date: dateStr,
      end_date: dateStr,
      work_type: workCell,
      color_hex: getColorForWorkType(workCell),
    })
  }

  return schedules
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { fileBase64, myName, partnerName, targetYear, targetMonth } =
      await req.json()

    if (!fileBase64) throw new Error('fileBase64는 필수입니다')
    if (!myName) throw new Error('myName은 필수입니다')

    // Decode base64 → Uint8Array
    const binaryStr = atob(fileBase64)
    const bytes = new Uint8Array(binaryStr.length)
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i)
    }

    // Parse xlsx
    const workbook = XLSX.read(bytes, { type: 'array' })
    const sheetName = workbook.SheetNames[0]
    if (!sheetName) throw new Error('엑셀 파일에 시트가 없습니다')

    const sheet = workbook.Sheets[sheetName]
    const rows: unknown[][] = XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      defval: '',
    })

    if (rows.length === 0) throw new Error('엑셀 파일이 비어 있습니다')

    const mySchedules = extractSchedulesForName(
      rows,
      myName,
      targetYear,
      targetMonth,
    )
    const partnerSchedules = partnerName
      ? extractSchedulesForName(rows, partnerName, targetYear, targetMonth)
      : []

    return new Response(
      JSON.stringify({
        year: targetYear,
        month: targetMonth,
        mySchedules,
        partnerSchedules,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})
