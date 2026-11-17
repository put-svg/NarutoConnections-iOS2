# Naruto Connections v29 — External File Handoff

v29 ต่อยอดจาก v28 โดยเพิ่มการส่งออกไฟล์เกมที่เลือกในคลังผ่าน iOS Share Sheet เพื่อให้ผู้ใช้บันทึกไฟล์ลงแอป Files แล้วนำเข้า MeloNX ด้วยตนเอง

- ไม่ได้ฝัง MeloNX หรือ Emulator Core ในแอป
- ไม่ได้เพิ่ม URL scheme หรือการสั่งเปิดเกมอัตโนมัติที่ยังไม่มีเอกสารยืนยัน
- วิธีใช้งานและข้อจำกัด: `MELO_NX_FILE_HANDOFF_TH.md`
- Workflow สร้าง unsigned IPA อยู่ที่ `.github/workflows/build-unsigned-ipa.yml`

ตรวจด้วย Swift parser และตรวจ ZIP ได้ แต่ยังไม่ได้ Build ด้วย Xcode/macOS หรือทดสอบบน iPhone
