# เชื่อมต่อ Nintendo Switch Core (v28)

## สถานะจริง
Naruto Connections ยังไม่ได้ฝัง MeloNX หรือ Ryujinx core ลงใน IPA และยังไม่มี API/URL scheme ที่ยืนยันจากผู้พัฒนา MeloNX สำหรับสั่งเปิดเกมจาก Launcher โดยตรง v28 จึงเพิ่มทางลัดไปยังแหล่งทางการและคำเตือนเรื่อง JIT/entitlements เท่านั้น ไม่แสดงสถานะว่า Core พร้อมเล่น

## Core ที่ใช้เป็นตัวเลือกภายนอก
- เว็บไซต์: https://melonx.org/
- Repository และคู่มือ: https://github.com/nurtrino/MeloNX
- Releases: https://github.com/nurtrino/MeloNX/releases
- Repository ระบุว่า MeloNX ใช้ Ryujinx เป็นฐาน พัฒนาด้วย C# และ Swift และเผยแพร่ภายใต้ GPLv3 (ตรวจ LICENSE ของ revision ที่จะนำมาใช้ทุกครั้ง)

## ขั้นตอนใช้งานแบบแยกแอป
1. เปิดเว็บไซต์หรือ Repository ของ MeloNX จากปุ่มในหน้า Runtime
2. อ่าน README/ข้อกำหนดอุปกรณ์และดาวน์โหลดจากช่องทางที่โครงการระบุเท่านั้น
3. ติดตั้ง MeloNX ด้วยวิธี sideload ที่โครงการรองรับ ตรวจสอบลายเซ็นและแหล่งที่มา
4. MeloNX ระบุว่าจำเป็นต้องใช้ JIT; บน iOS 26 คู่มือระบุให้ใช้ StikDebug และอาจต้องมี memory entitlements ตามรุ่นอุปกรณ์/วิธีติดตั้ง
5. เพิ่ม firmware, encryption keys และเกมที่ผู้ใช้ dump เองและมีสิทธิ์ใช้งาน ภายใน MeloNX ตามคู่มือของโครงการเท่านั้น
6. เปิดเกมจากภายใน MeloNX เอง

## ข้อจำกัด
- การติดตั้งด้วย ESign อย่างเดียวไม่ได้รับประกัน JIT หรือ Increased Memory Limit / Extended Virtual Addressing
- ไม่รวม firmware, keys, เกม หรือ DLC ที่มีลิขสิทธิ์ไว้ในโปรเจกต์
- ไฟล์เกมที่นำเข้า Naruto Connections ยังเป็นเพียงไฟล์ที่จัดเก็บใน sandbox ของแอป ไม่ได้ส่งต่อให้ MeloNX อัตโนมัติ
- การฝัง Core จริงต้องพอร์ต .NET iOS และ native dependencies, ตรวจ architecture/entitlements, ปฏิบัติตาม GPLv3 และทดสอบบนอุปกรณ์จริง เป็นงานแยกที่ยังไม่เสร็จ

## แหล่งอ้างอิงที่ตรวจเมื่อ 17 พ.ย. 2026
- https://github.com/nurtrino/MeloNX
- https://github.com/nurtrino/MeloNX/releases
- https://melonx.org/
