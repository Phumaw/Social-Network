# Social Network

แอปโซเชียลเน็ตเวิร์กที่พัฒนาด้วย Flutter มีระบบโพสต์ ค้นหาผู้ใช้และชุมชน
แชต และจัดการโปรไฟล์ ส่วน API ใช้ Express และ MongoDB

## สิ่งที่ต้องติดตั้ง

- Flutter 3.44.6 (Dart 3.12.2) หรือเวอร์ชันที่เข้ากันได้กับ `pubspec.yaml`
- Node.js และ npm สำหรับ API
- MongoDB ที่เข้าถึงได้จาก API
- Android Studio สำหรับ Android; macOS และ Xcode สำหรับ build/upload ไป TestFlight

## เริ่มใช้งานในเครื่อง

สร้าง `backend/.env` ก่อน โดยกำหนด `MONGO_URI`, `JWT_SECRET` และค่าตั้ง SMTP
ตามที่อธิบายใน [backend/README.md](backend/README.md) จากนั้นติดตั้ง dependency
และเริ่ม API ใน PowerShell:

```powershell
cd backend
npm ci
npm run dev
```

อย่า commit ไฟล์ `.env` หรือใส่ secret ลงใน source code

จากโฟลเดอร์โปรเจกต์ Flutter:

```powershell
flutter pub get
flutter run
```

ค่า API เริ่มต้นใช้ Android emulator (`http://10.0.2.2:3000/api`) หรือ web/iOS
simulator (`http://127.0.0.1:3000/api`) สำหรับมือถือจริงหรือ production ให้ใช้
API ที่เข้าถึงได้ผ่าน HTTPS:

```powershell
flutter run --dart-define=API_BASE_URL=https://api.example.com/api
```

รายละเอียด API และตัวแปรแวดล้อมอยู่ใน [backend/README.md](backend/README.md)

## เชื่อมโปรเจกต์กับ GitHub

1. สร้าง repository ใหม่บน GitHub โดยไม่เลือกสร้าง README, `.gitignore`
   หรือ License ซ้ำ
2. เปิด PowerShell ที่โฟลเดอร์โปรเจกต์ แล้วตั้งค่า Git ครั้งแรก:

   ```powershell
   git init -b main
   git add .
   git commit -m "Initial project"
   git remote add origin https://github.com/<OWNER>/<REPOSITORY>.git
   git push -u origin main
   ```

   แทน `<OWNER>` และ `<REPOSITORY>` ด้วยชื่อบัญชี/องค์กรและ repository ของคุณ
   หาก Git แจ้งว่า repository ถูกสร้างไว้แล้ว ให้ข้าม `git init` และเพิ่ม remote
   ด้วย `git remote add origin ...` เท่านั้น
3. ใน GitHub เปิด **Settings → Secrets and variables → Actions → Variables**
   แล้วเพิ่ม repository variable:

   | Name | Value |
   |---|---|
   | `API_BASE_URL` | URL HTTPS ของ API ที่ deploy แล้ว ลงท้ายด้วย `/api` |

4. Workflow ใน `.github/workflows/ci-android.yml` จะรัน analyze, tests และสร้าง
   APK สำหรับทดสอบทุกครั้งที่ push หรือเปิด Pull Request ไปยัง repository
   ดาวน์โหลดได้จากหน้า run ใน **Actions → Artifacts** (เก็บไว้ 14 วัน)

ล็อกอิน GitHub ด้วย browser authentication เมื่อ Git Credential Manager ถาม
อย่าใส่ Personal Access Token ในคำสั่งหรือ commit ลงใน repository

## สร้าง APK

APK สำหรับติดตั้งทดสอบในเครื่อง:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://api.example.com/api
```

ไฟล์อยู่ที่ `build/app/outputs/flutter-apk/app-debug.apk` สำหรับติดตั้งผ่าน ADB:

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

APK จาก GitHub Actions เป็น debug build สำหรับทดสอบเท่านั้น ไม่ใช่ไฟล์สำหรับ
Google Play หรือเผยแพร่ให้ผู้ใช้ทั่วไป ขณะนี้ Android application ID ยังเป็น
`com.example.foodiehub` และ build แบบ release ยังใช้ debug signing key
ก่อนเผยแพร่จริงให้เปลี่ยน application ID เป็นชื่อเฉพาะของแอป และตั้งค่า
release keystore/signing secrets ใน Gradle และ GitHub Actions

## อัปโหลดไป TestFlight

การ build และลงนามแอป iOS ต้องใช้ macOS, Xcode และ Apple Developer Program
จึงไม่สามารถสร้างไฟล์ TestFlight บน Windows ได้

1. เปลี่ยน iOS Bundle Identifier ปัจจุบัน (`com.example.foodiehub`) ให้เป็น
   identifier ที่ไม่ซ้ำ และสร้างแอปด้วย identifier เดียวกันใน App Store Connect
2. บน Mac เปิด `ios/Runner.xcworkspace` ด้วย Xcode เลือก target `Runner`,
   ตั้งค่า **Signing & Capabilities → Team** และใช้ provisioning แบบที่ Apple
   Developer account ของคุณอนุญาต
3. ที่โฟลเดอร์โปรเจกต์ รัน:

   ```bash
   flutter pub get
   flutter build ipa --release \
     --build-name=1.0.0 \
     --build-number=1 \
     --dart-define=API_BASE_URL=https://api.example.com/api
   ```

4. ส่งไฟล์ `build/ios/ipa/*.ipa` ผ่านแอป Transporter หรือ Xcode Organizer ไปยัง
   App Store Connect จากนั้นเลือก build ในหน้า **TestFlight** และเพิ่มผู้ทดสอบ
5. การแจกจ่ายให้ผู้ทดสอบภายนอกอาจต้องผ่าน Beta App Review ของ Apple

การอัปโหลด TestFlight จาก GitHub Actions ยังไม่ได้ตั้งค่า เพราะต้องมี Apple
Developer Team, Bundle ID, signing certificate และ provisioning profile ของ
เจ้าของแอปก่อน อย่าเก็บ certificate หรือ private key ไว้ใน Git; หากต้องการ
ทำขั้นตอนนี้อัตโนมัติ ให้จัดเก็บเป็น GitHub Actions secrets และใช้ macOS runner

## ตรวจสอบก่อนส่งงาน

```powershell
flutter analyze
flutter test
```
