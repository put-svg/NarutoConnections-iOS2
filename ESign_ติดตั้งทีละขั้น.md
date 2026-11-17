# วิธีนำ IPA ไปติดตั้งใน ESign

## A. สร้าง IPA จาก GitHub
1. เปิด Repository ใน GitHub
2. ตรวจว่ามีโฟลเดอร์ `.github/workflows` และไฟล์ `build-unsigned-ipa.yml`
3. แตะ **Actions** → **Build unsigned iOS IPA** → **Run workflow** → **Run workflow**
4. รอจน Build สำเร็จเป็นสีเขียว
5. เปิด Run นั้น แล้วเลื่อนลงไปที่ **Artifacts**
6. แตะ `NarutoConnections-unsigned-IPA` เพื่อดาวน์โหลดและแตก ZIP
7. เก็บไฟล์ `NarutoConnections-unsigned.ipa` ไว้ในแอป Files

## B. Sign และ Install ใน ESign
1. เปิด ESign และนำเข้า `NarutoConnections-unsigned.ipa`
2. เลือกคำสั่ง Sign ของ ESign
3. เลือก Certificate และ Provisioning Profile ที่คุณมีสิทธิ์ใช้งาน
4. ตรวจว่า Provisioning Profile อนุญาต Bundle ID `com.narutoconnections.launcher`
5. สั่ง Sign และรอจน ESign แจ้งว่าสำเร็จ
6. กด Install แล้วทำตามหน้าจอ iPhone

## ถ้าติดตั้งไม่ได้
- `No matching provisioning profile`: Profile ไม่ตรง Bundle ID หรือไม่มี App ID นี้
- `ApplicationVerificationFailed` / `Unable to Install`: ตรวจ Certificate, Profile, วันหมดอายุ และการลงทะเบียนอุปกรณ์
- ถ้า ESign แจ้งว่า Sign ไม่สำเร็จ ให้ส่งภาพข้อความ Error มาได้ โดยปิดบังข้อมูลส่วนตัวก่อน

## ความปลอดภัย
อย่าส่ง P12, รหัสผ่าน P12, Apple ID หรือโทเคน GitHub ให้ใคร และอย่าใช้ Certificate ขององค์กรอื่นโดยไม่ได้รับอนุญาต
