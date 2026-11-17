# v30 – ปรับ Workflow สำหรับปัญหา Hosted Runner

รุ่นนี้ต่อจาก v29 และแก้ workflow ให้มีขั้นตรวจไฟล์บน Ubuntu ก่อน แล้วจึงจัดสรร macOS สำหรับ Xcode build

## สิ่งที่เปลี่ยน
- ค่าเริ่มต้นเปลี่ยนเป็น `macos-15-intel` ซึ่งเป็น runner pool ทางเลือก
- เพิ่มตัวเลือก `macos-15` และ `macos-14` ในหน้า Run workflow
- เพิ่มงาน `Source preflight (Ubuntu)` เพื่อแยกปัญหาไฟล์โปรเจกต์ออกจากปัญหาจัดสรร macOS runner
- เปลี่ยนเป็น `workflow_dispatch` เพื่อให้เลือก runner pool ได้เอง

## วิธีใช้
1. แตก ZIP แล้วอัปโหลดเนื้อหาใน `naruto_proj` ไปยัง root ของ GitHub repository โดยแทนที่ไฟล์เดิม
2. เปิด Actions → Build unsigned iOS IPA → Run workflow
3. เลือก `macos-15-intel` ก่อน (ค่าเริ่มต้น)
4. ถ้างาน Ubuntu ผ่าน แต่งาน macOS ล้มเหลวก่อนเริ่ม step พร้อมข้อความ `The job was not acquired...` แสดงว่าเป็นปัญหาจัดสรร Hosted Runner ไม่ใช่ compile error ในโค้ด
5. ถ้าจัดสรร runner ได้แต่ Build ล้มเหลว ให้ดู log ใน step `Build app for iPhone (unsigned)` แล้วแก้ตาม error นั้น

## ข้อจำกัด
การเปลี่ยน runner pool อาจช่วยได้หาก pool เดิมขาด capacity แต่ไม่สามารถแก้ outage หรือข้อจำกัดฝั่ง GitHub ได้แน่นอน งาน iOS Xcode build ยังต้องใช้ macOS; Ubuntu preflight ตรวจได้เฉพาะไฟล์ต้นทาง ไม่ได้สร้าง IPA

IPA ที่สร้างยังเป็น unsigned ต้องเซ็นด้วย certificate และ provisioning profile ที่ถูกต้องก่อนติดตั้งผ่าน ESign
