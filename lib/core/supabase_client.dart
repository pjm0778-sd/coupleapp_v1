import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://kjjrpmnnyxrdeikvcjkv.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqanJwbW5ueXhyZGVpa3Zjamt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwNDI4MTcsImV4cCI6MjA4ODYxODgxN30.A6RD15wWFAEvsZHf9-5OZYeUwkd9hJUESijOUWbT6Sg';

/// 전역 Supabase 클라이언트 접근자
SupabaseClient get supabase => Supabase.instance.client;
