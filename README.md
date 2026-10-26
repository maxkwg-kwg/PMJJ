# Team Jahja นักล่า PM

แอปทีมจ๊ะจ๋า: ตารางวิวรายสัปดาห์ (นัดดูห้อง / Booking / Success) และเครื่องคิดเลขราคาขาย NET ↔ ราคาตั้งขาย
เป็นเว็บไฟล์เดียว ไม่ต้อง build ใช้ Supabase เก็บข้อมูลและล็อกอินรายคน

## ไฟล์
- `index.html` ตัวแอป
- `config.js` ใส่ค่า Supabase (ขั้นที่ 2)
- `supabase/schema.sql` สร้างตารางและสิทธิ์ (ขั้นที่ 1)
- `seed.sql` (ไม่อยู่ใน repo นี้ เพราะมีข้อมูลลูกค้า) รันใน Supabase จากไฟล์ที่ได้แยกไว้

## ขั้นที่ 1: ตั้งค่า Supabase (ฟรี)
1. สมัครที่ https://supabase.com แล้วกด New project (เลือก Region: Singapore)
2. เข้า **SQL Editor** แล้ววางไฟล์ `supabase/schema.sql` กด Run
3. วางไฟล์ `seed.sql` (ไฟล์แยก ไม่อยู่ใน repo) กด Run เพื่อย้ายนัดเดิมมา
4. **Authentication > URL Configuration**: ใส่ Site URL เป็นลิงก์ Vercel ของแอป (หลังขั้นที่ 3)
5. ถ้าไม่อยากให้ทีมต้องยืนยันอีเมลตอนสมัคร: **Authentication > Sign In / Providers > Email** ปิด "Confirm email"

## ขั้นที่ 2: ใส่ค่าใน config.js
ไปที่ **Project Settings > API** คัดลอก
- Project URL → `SUPABASE_URL`
- anon public key → `SUPABASE_ANON_KEY`

## ขั้นที่ 3: ขึ้น Vercel
- ผ่าน GitHub: push โฟลเดอร์นี้ขึ้น repo แล้วที่ https://vercel.com/new กด Import repo นั้น
  (Framework Preset: Other, ไม่ต้องตั้ง Build Command) แก้โค้ดครั้งต่อไป push แล้ว Vercel อัปเดตเอง
- หรือลากโฟลเดอร์นี้ไปที่หน้า Vercel โดยตรง

## เพิ่ม/ลบสมาชิกทีม
Supabase > **Table Editor > team_members** เพิ่มแถว: `email` (อีเมลที่เขาจะใช้สมัคร) และ `name`
คนนั้นเปิดแอป กด "สมัครบัญชี" ด้วยอีเมลนั้น ตั้งรหัสผ่านเอง แล้วเข้าใช้ได้
ลบแถวออก = คนนั้นเข้าดู/แก้นัดไม่ได้อีก (เครื่องคิดเลข NET ใช้ได้ทุกคนโดยไม่ต้องล็อกอิน)

## ความปลอดภัย
- anon key อยู่ในหน้าเว็บได้ตามปกติของ Supabase ข้อมูลป้องกันด้วย Row Level Security: อ่าน/เขียนได้เฉพาะอีเมลใน `team_members`
- อย่าใส่ **service_role key** ในไฟล์ใดๆ ของแอป
