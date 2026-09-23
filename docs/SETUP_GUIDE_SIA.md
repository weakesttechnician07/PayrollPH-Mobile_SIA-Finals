# PayrollPH – Laravel 12 + Flutter SIA Setup Guide
**IT224 – Systems Integration and Architecture**

---

## Prerequisites

Install these before starting:

| Tool | Download | Notes |
|---|---|---|
| XAMPP | https://www.apachefriends.org | For Apache + MySQL (port 3307) |
| Composer | https://getcomposer.org | PHP dependency manager |
| Flutter SDK | https://flutter.dev/docs/get-started/install | Extract to `D:\flutter` or `C:\flutter` — no spaces in path |
| Android Studio | https://developer.android.com/studio | Required for Android SDK + emulator |
| VS Code | https://code.visualstudio.com | Recommended editor |
| Git | https://git-scm.com | Version control |

> ⚠️ **Important:** Make sure XAMPP is already installed and the `payroll_system` database is already imported from `payroll_system.sql` before starting the Laravel setup.

---

## Part 1 — Laravel 12 REST API

### Step 1 — Create a New Laravel Project

```bash
composer create-project laravel/laravel payroll-laravel
cd payroll-laravel
```

### Step 2 — Install Laravel Sanctum

```bash
php artisan install:api
```

> When asked to run migrations, type `yes`.
>
> ⚠️ **Known issue:** If you see `Table 'users' already exists` or `Table 'personal_access_tokens' already exists`, open the offending migration file in `database/migrations/` and blank out the `up()` method:
> ```php
> public function up(): void
> {
>     // Skipped — table already exists from payroll_system SQL import
> }
> public function down(): void { }
> ```
> Then run `php artisan migrate` again.

### Step 3 — Configure the Database (.env)

Open `.env` and update the database section:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3307
DB_DATABASE=payroll_system
DB_USERNAME=root
DB_PASSWORD=
```

> Port **3307** — this project uses XAMPP with MySQL on port 3307, not the default 3306.

Also add these to avoid cache table errors:

```env
CACHE_DRIVER=file
SESSION_DRIVER=file
```

### Step 4 — Configure bootstrap/app.php (Laravel 12)

> ⚠️ Laravel 12 does **not** use `app/Http/Kernel.php`. Do NOT follow Laravel 10 tutorials that reference Kernel.php — it doesn't exist in Laravel 12.

Open `bootstrap/app.php` and make sure it looks like this:

```php
<?php
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->statefulApi();
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();
```

### Step 5 — Configure CORS

Open `config/cors.php`:

```php
'paths' => ['api/*', 'sanctum/csrf-cookie'],
'allowed_methods' => ['*'],
'allowed_origins' => ['*'],
'allowed_origins_patterns' => [],
'allowed_headers' => ['*'],
'supports_credentials' => false,
```

### Step 6 — Configure config/auth.php

Open `config/auth.php` and verify the guards section:

```php
'guards' => [
    'web' => ['driver' => 'session', 'provider' => 'users'],
    'api' => ['driver' => 'sanctum',  'provider' => 'users'],
],
'providers' => [
    'users' => ['driver' => 'eloquent', 'model' => App\Models\User::class],
],
```

### Step 7 — Copy Project Files

Create the API controllers folder first:

```bash
mkdir app\Http\Controllers\Api
```

Copy each file to its correct Laravel location:

| Source File | Laravel Destination |
|---|---|
| `routes_api.php` | `routes/api.php` (replace existing) |
| `AuthController.php` | `app/Http/Controllers/Api/` |
| `DashboardController.php` | `app/Http/Controllers/Api/` |
| `EmployeeController.php` | `app/Http/Controllers/Api/` |
| `PayrollController.php` | `app/Http/Controllers/Api/` |
| `AttendanceController.php` | `app/Http/Controllers/Api/` |
| `BenefitsController.php` | `app/Http/Controllers/Api/` |
| `RequestController.php` | `app/Http/Controllers/Api/` |
| `WarehouseController.php` | `app/Http/Controllers/Api/` |
| `UserController.php` | `app/Http/Controllers/Api/` |
| `User.php` | `app/Models/User.php` (replace existing) |
| `AuditLog.php` | `app/Models/AuditLog.php` |

### Step 8 — Run the Additional SQL (Section 9 Features)

Open phpMyAdmin → select `payroll_system` → click the **SQL** tab.

Paste and run the contents of `section9_new_features.sql`.

This adds:
- `attendance` table (days_worked, days_absent, days_present computed column)
- `requests` table (employee request/approval workflow)
- `vw_payroll_preview` view (attendance-aware prorated salary)
- `vw_requests` view (request list with reviewer names)
- Performance indexes

### Step 9 — Clear Cache and Start the Server

```bash
php artisan config:clear
php artisan cache:clear
php artisan serve
```

> If `php artisan cache:clear` fails with a cache table error, that's expected — it's resolved by setting `CACHE_DRIVER=file` in Step 3.

The API is now running at: `http://127.0.0.1:8000`

All endpoints are available at: `http://127.0.0.1:8000/api/...`

### Step 10 — Test the API (Thunder Client / Postman)

**Using Thunder Client (VS Code extension — recommended):**
1. Open VS Code → click the ⚡ Thunder Client icon in the sidebar
2. Click **New Request** → set method to **POST**
3. Enter URL: `http://127.0.0.1:8000/api/login`
4. Click **Body → JSON** and paste:
```json
{ "username": "admin", "password": "password" }
```
5. Click **Send** — you should receive a `token` in the response ✅

Use that token as `Authorization: Bearer <token>` for all subsequent requests.

---

## Part 2 — Flutter Mobile App

### Step 1 — Install Flutter SDK

**Windows:**
1. Download from https://flutter.dev/docs/get-started/install/windows
2. Extract to `D:\flutter` — **do NOT use a path with spaces** (e.g. avoid `Program Files`)
3. Add `D:\flutter\bin` to your system PATH:
   - Search **"Environment Variables"** in Windows
   - Edit **System variables → Path → New**
   - Add `D:\flutter\bin`
4. Restart terminal, then verify: `flutter --version`

**Mac:**
1. Download from https://flutter.dev/docs/get-started/install/macos
2. Extract to `~/flutter`
3. Add to `~/.zshrc`: `export PATH="$PATH:$HOME/flutter/bin"`
4. Run: `source ~/.zshrc` then `flutter --version`

### Step 2 — Install Android Studio

1. Download from https://developer.android.com/studio
2. Install with default options
3. Open Android Studio → **More Actions → SDK Manager → SDK Tools tab**
4. Check: Android SDK Build-Tools, Android Emulator, Android SDK Platform-Tools
5. Click **Apply → OK**

### Step 3 — Accept Android Licenses

```bash
flutter doctor --android-licenses
```

Type `y` and Enter for each prompt.

### Step 4 — Set Up Emulator (optional — skip if using real device)

1. Android Studio → **More Actions → Virtual Device Manager → Create Device**
2. Select: **Pixel 6** → Next
3. Select system image: **API 35** → Download if needed → Next → Finish
4. Press **▶ Play** to start the emulator

> ⚠️ **AVD storage:** By default, AVD data is saved to `C:\Users\username\.android\avd\`. If your C: drive is low on space, set `ANDROID_AVD_HOME=D:\AndroidAVD` as a system environment variable before creating the AVD.

### Step 5 — Enable Windows Developer Mode

Flutter requires symlinks on Windows. Run:

```powershell
start ms-settings:developers
```

Toggle **Developer Mode** to **On** and confirm.

### Step 6 — Generate Android Platform Files

If the `android/` folder doesn't exist in the Flutter project (e.g. after a fresh clone):

```bash
cd flutter_app
flutter create .
```

> ⚠️ This regenerates Android config files. After running it, replace `android/app/build.gradle.kts`, `android/gradle.properties`, and `android/gradle/wrapper/gradle-wrapper.properties` with the correct versions (see Step 8).

### Step 7 — Install Dependencies

```bash
cd flutter_app
flutter pub get
```

### Step 8 — Android Build Configuration

These files must have the exact settings below — `flutter create .` may reset them.

**`android/app/build.gradle.kts`:**
```kotlin
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.example.payroll_ph_v2"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
    defaultConfig {
        applicationId = "com.example.payroll_ph_v2"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("debug") }
    }
}
flutter { source = "../.." }
```

**`android/gradle.properties`:**
```properties
org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
kotlin.incremental=false
```

**`android/gradle/wrapper/gradle-wrapper.properties`:**
```properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-9.1.0-all.zip
```

**`android/build.gradle.kts` (root — add the subprojects block):**
```kotlin
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            extensions.findByType(com.android.build.gradle.BaseExtension::class)?.apply {
                compileSdkVersion(36)
            }
        }
    }
}
```

**`android/app/src/main/AndroidManifest.xml`** — add inside `<application`:
```xml
android:usesCleartextTraffic="true"
android:label="PayrollPH v2"
```

### Step 9 — Update the API URL

Open `lib/services/api_service.dart`:

```dart
// Android Emulator:
static const String baseUrl = 'http://10.0.2.2:8000/api';

// Real Physical Device (use your PC's IP from ipconfig):
static const String baseUrl = 'http://192.168.x.x:8000/api';
```

Find your PC's IP:
```powershell
ipconfig
# Look for IPv4 Address under your active network adapter
```

### Step 10 — Connect a Real Device (optional)

1. On your Android phone: **Settings → About Phone → tap Build Number 7 times**
2. Go to **Developer Options → enable USB Debugging**
3. Connect via USB → tap **Allow** on the phone when prompted
4. Verify: `flutter devices` — your phone should appear

### Step 11 — Run the App

**Start XAMPP first** (Apache + MySQL), then Laravel:

```powershell
# Terminal 1 — Laravel (real device needs --host flag)
php artisan serve --host=0.0.0.0 --port=8000

# Terminal 2 — Flutter
flutter run
```

Select your device when prompted. First build takes 3–5 minutes.

---

## API URL Quick Reference

| Setup | `baseUrl` in api_service.dart | Laravel Command |
|---|---|---|
| Android Emulator | `http://10.0.2.2:8000/api` | `php artisan serve` |
| Real Device (USB) | `http://YOUR_PC_IP:8000/api` | `php artisan serve --host=0.0.0.0` |

---

## Flutter Terminal Shortcuts (while `flutter run` is active)

| Key | Action |
|---|---|
| `r` | Hot reload — apply code changes instantly |
| `R` | Hot restart — restart app, clear state |
| `q` | Quit — stop debug session cleanly |
| `d` | Detach — app stays on phone, ends debug session |

---

## Common Errors & Fixes

| Error | Fix |
|---|---|
| `Table 'users' already exists` during migration | Blank out `up()` in the migration file — table already exists from SQL import |
| `Table 'cache' doesn't exist` | Add `CACHE_DRIVER=file` and `SESSION_DRIVER=file` to `.env` |
| `No supported devices connected` after `flutter create .` | Run `flutter create .` to generate the `android/` folder, then restore build config files |
| `Please enable Developer Mode` | Run `start ms-settings:developers` and enable Developer Mode |
| `file_picker` build error (v1 embedding removed) | Set `file_picker: ^11.0.0` in `pubspec.yaml`, then run `flutter pub cache clean && flutter pub get` |
| `build.gradle.kts` compilation errors (deprecated DSL) | Remove `kotlin { }` and `kotlinOptions { }` blocks entirely from `android/app/build.gradle.kts` |
| `:file_picker compiled against android-34` | Add `compileSdkVersion(36)` override in root `android/build.gradle.kts` via `afterEvaluate` block |
| `ClassNotFoundException: MainActivity` | Move `MainActivity.kt` to `android/.../payroll_ph_v2/` folder and update package declaration |
| `Could not close incremental caches` (Kotlin lock) | Run `taskkill /f /im java.exe` then `flutter clean && flutter pub get` |
| Connection refused on login (real device) | Confirm phone and PC are on same WiFi; use `--host=0.0.0.0` for Laravel; check IP hasn't changed |
| `rd /s /q` fails in PowerShell | Use `Remove-Item -Recurse -Force` instead |

---

*PayrollPH v2 — IT224 Systems Integration and Architecture*
*Laravel 12 · Flutter · MariaDB 10.4 · Android SDK 36 · Java 21 · Gradle 9.1.0*
*Last updated: May 2026*
