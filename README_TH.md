# Naruto Connections iOS Launcher — v26

เวอร์ชันนี้ปรับ workflow สำหรับสร้าง unsigned IPA ให้เลือก macOS hosted runner ได้ 2 แบบ (`macos-14` และ `macos-15`) จากหน้า Run workflow เพื่อใช้เป็นทางเลือกเมื่อ runner ตัวหนึ่งจัดสรรเครื่องไม่ได้


## v26 — Game Controller Input Bridge
- อ่านชื่อจอยที่เชื่อมต่อผ่าน GameController API ของ iOS
- อ่านอินพุตจริงจากปุ่ม A/B/X/Y, L1/R1, Menu, D-pad และแกนอนาล็อกซ้าย
- แสดงอินพุตล่าสุดในหน้าปุ่มควบคุม เพื่อทดสอบจอยก่อนเชื่อมกับ Runtime
- การอ่านอินพุตนี้ยังไม่ใช่การควบคุมเกม เพราะโปรเจกต์ยังไม่มี Emulator Core

## วิธีใช้
1. อัปโหลด/แทนที่ไฟล์ใน repository ด้วยเนื้อหาในโฟลเดอร์ `naruto_proj` โดยคงโครงสร้างโฟลเดอร์ไว้
2. เปิดแท็บ **Actions** แล้วเลือก **Build unsigned iOS IPA**
3. กด **Run workflow** และเลือก `macos-14` ก่อน
4. หากขึ้นปัญหาจัดสรร Hosted Runner อีก ให้ลอง Run workflow ใหม่โดยเลือก `macos-15` (ไม่ใช่ Re-run job เดิม)
5. เมื่อสำเร็จ ดาวน์โหลด artifact ชื่อ `NarutoConnections-unsigned-IPA`

## ข้อจำกัด
- การเปลี่ยน runner เป็นเพียงทางเลือกแก้ปัญหาการจัดสรรเครื่อง ไม่รับประกันว่าจะข้ามปัญหาฝั่ง GitHub-hosted service ได้ทุกกรณี
- IPA ที่ได้เป็น **unsigned** ต้องลงลายเซ็นด้วย certificate และ provisioning profile ที่ถูกต้องและได้รับอนุญาตก่อนติดตั้ง
- โปรเจกต์นี้ยังเป็น Launcher/คลังไฟล์และ Runtime bridge เท่านั้น ไม่มี Emulator Core สำหรับเล่นเกมจริง
- Workflow ยังต้องใช้ GitHub Actions hosted macOS runner และ Xcode; ไม่สามารถสร้าง IPA บน iPhone ผ่าน ESign เพียงอย่างเดียวได้

## v27 — Switch Core selection / external-core setup
- เลือก MeloNX เป็น Nintendo Switch emulator อ้างอิง พร้อมคู่มือการติดตั้งและข้อกำหนด (`MELO_NX_CORE_SETUP_TH.md`)
- ปรับข้อความตรวจไฟล์ `.NSP/.XCI` ให้บอกตรง ๆ ว่าต้องใช้ MeloNX แยกต่างหาก
- เพิ่มบันทึกแหล่งที่มาและเงื่อนไข GPLv3 (`CORE_SOURCE_NOTICES.md`)
- **ยังไม่ได้ฝัง MeloNX, ยังไม่มีการเปิดเกมข้ามแอป และยังเล่นเกมจาก Launcher นี้ไม่ได้** เพราะ MeloNX เป็นแอป/โครงการ emulator ขนาดใหญ่ที่มี C#, Swift และ native dependencies ไม่ใช่ Swift framework ที่ลิงก์ได้ทันที


## v30: Hosted Runner troubleshooting
ดูคู่มือ `README_V30_RUNNER_FIX_TH.md` สำหรับการเลือก macOS runner pool และแยก preflight ออกจาก Xcode build
