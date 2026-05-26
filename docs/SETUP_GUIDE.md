# PayrollPH SIA v2 — Complete Setup Guide
# IT224 Systems Integration and Architecture
# Laravel 12 + Flutter + MySQL (XAMPP)

═══════════════════════════════════════════════════════════
OVERVIEW
═══════════════════════════════════════════════════════════

This guide walks you through setting up the full PayrollPH
integrated system:

  1. Prerequisites (what you need installed)
  2. Laravel 12 Backend (REST API)
  3. Flutter Mobile App
  4. Connecting everything together
  5. Default accounts and test credentials
  6. Common errors and fixes

Estimated setup time: 30–45 minutes

═══════════════════════════════════════════════════════════
PART 0: PREREQUISITES
═══════════════════════════════════════════════════════════

You need the following installed BEFORE starting:

A. XAMPP (already installed - you have this)
   - Apache + MySQL must be running
   - Your payroll_system database must be imported
   - Access phpMyAdmin at http://localhost/phpmyadmin

B. PHP 8.2 or higher (required by Laravel 12)
   - Check your version: open Command Prompt and type:
     php --version
   - XAMPP ships with PHP. If below 8.2, update XAMPP.
   - Download latest XAMPP: https://www.apachefriends.org

C. Composer (PHP dependency manager)
   - Check if installed: composer --version
   - If not installed, download from: https://getcomposer.org
   - Windows: download and run Composer-Setup.exe
   - During install, point it to your XAMPP php.exe:
     C:\xampp\php\php.exe
   - After install, restart Command Prompt and verify:
     composer --version  →  should show Composer 2.x.x

D. Git (for version control - you already have this)
   - Verify: git --version

═══════════════════════════════════════════════════════════
PART 1: LARAVEL 12 BACKEND SETUP
═══════════════════════════════════════════════════════════

STEP 1 — Create a new Laravel 12 project
─────────────────────────────────────────
Open Command Prompt in a folder where you want the project
(e.g., your Desktop or Documents), then run:

  composer create-project laravel/laravel payroll-laravel

This downloads Laravel 12 and all dependencies.
It takes 2–5 minutes depending on your internet speed.

When done, enter the project folder:

  cd payroll-laravel

STEP 2 — Install Laravel Sanctum (API token auth)
──────────────────────────────────────────────────
Sanctum handles the Bearer token system for mobile login.

  composer require laravel/sanctum

Then publish Sanctum's config:

  php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"

Run the Sanctum migration (creates personal_access_tokens table):

  php artisan migrate

STEP 3 — Configure the database (.env file)
────────────────────────────────────────────
In the payroll-laravel folder, find the file named .env
Open it with VS Code or Notepad.

Find the DB_ section and update it to match your XAMPP:

  DB_CONNECTION=mysql
  DB_HOST=127.0.0.1
  DB_PORT=3306
  DB_DATABASE=payroll_system
  DB_USERNAME=root
  DB_PASSWORD=

NOTE: If your XAMPP MySQL runs on port 3307 (as in your case),
change DB_PORT=3306 to DB_PORT=3307

STEP 4 — Create the Api controllers folder
───────────────────────────────────────────
  mkdir app\Http\Controllers\Api

STEP 5 — Copy all project files from the ZIP
─────────────────────────────────────────────
From the sia_v2/laravel_api/ folder in the ZIP, copy:

  FILE IN ZIP                              →  DESTINATION IN LARAVEL PROJECT
  ─────────────────────────────────────────────────────────────────────────
  routes_api.php                           →  routes/api.php (replace existing)
  Controllers/AuthController.php           →  app/Http/Controllers/Api/
  Controllers/DashboardController.php      →  app/Http/Controllers/Api/
  Controllers/EmployeeController.php       →  app/Http/Controllers/Api/
  Controllers/PayrollController.php        →  app/Http/Controllers/Api/
  Controllers/AttendanceController.php     →  app/Http/Controllers/Api/
  Controllers/BenefitsController.php       →  app/Http/Controllers/Api/
  Controllers/RequestController.php        →  app/Http/Controllers/Api/
  WarehouseUserController.php              →  Split manually (see note below)
  Models/User.php                          →  app/Models/User.php (REPLACE existing)
  Models/AuditLog.php                      →  app/Models/AuditLog.php

NOTE on WarehouseUserController.php:
  Open the file - it contains two classes.
  Split it into two files:
    app/Http/Controllers/Api/WarehouseController.php  ← copy the WarehouseController class
    app/Http/Controllers/Api/UserController.php       ← copy the UserController class
  Add the correct namespace and imports to each.

STEP 6 — Update app/Http/Kernel.php (Sanctum middleware)
─────────────────────────────────────────────────────────
NOTE: In Laravel 12, the Kernel.php structure changed.
If your project has bootstrap/app.php instead of Kernel.php,
use this approach instead:

Open bootstrap/app.php and ensure it looks like:

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

The ->withMiddleware(function($m){ $m->statefulApi(); })
line is the Laravel 12 equivalent of adding Sanctum to the
api middleware group.

STEP 7 — Configure CORS (for Flutter mobile access)
────────────────────────────────────────────────────
Open config/cors.php and update:  

  'paths' => ['api/*', 'sanctum/csrf-cookie'],
  'allowed_methods' => ['*'],
  'allowed_origins' => ['*'],
  'allowed_origins_patterns' => [],
  'allowed_headers' => ['*'],
  'exposed_headers' => [],
  'max_age' => 0,
  'supports_credentials' => false,

STEP 8 — Configure config/auth.php
────────────────────────────────────
Open config/auth.php. Find the 'guards' section and verify:

  'guards' => [
      'web' => [
          'driver' => 'session',
          'provider' => 'users',
      ],
      'api' => [
          'driver' => 'sanctum',
          'provider' => 'users',
      ],
  ],

  'providers' => [
      'users' => [
          'driver' => 'eloquent',
          'model' => App\Models\User::class,
      ],
  ],

STEP 9 — Run the new SQL additions
────────────────────────────────────
Open phpMyAdmin → click payroll_system → SQL tab.
Paste and run the contents of: section9_new_features.sql

This adds:
  - requests table (employee request system)
  - attendance.working_days column
  - vw_payroll_preview view (attendance-aware)
  - vw_requests view
  - Performance indexes

STEP 10 — Clear config cache and start the server
──────────────────────────────────────────────────
  php artisan config:clear
  php artisan cache:clear
  php artisan serve

The API is now running at: http://127.0.0.1:8000

STEP 11 — Verify it works
──────────────────────────
Open your browser and go to:
  http://127.0.0.1:8000/api/login

You should see a 405 Method Not Allowed (correct! it needs POST)
or open Postman and POST to that URL with:
  { "username": "admin", "password": "password" }

You should receive a JSON response with a token. ✅

═══════════════════════════════════════════════════════════
PART 2: FLUTTER MOBILE APP SETUP
═══════════════════════════════════════════════════════════

STEP 1 — Install Flutter SDK
──────────────────────────────

Windows:
  1. Go to: https://flutter.dev/docs/get-started/install/windows
  2. Click "Download Flutter SDK" (get the .zip file)
  3. Extract it to C:\flutter
     (IMPORTANT: Do NOT put it in C:\Program Files — no spaces in path!)
  4. Add Flutter to your PATH:
     - Search "Environment Variables" in Windows search
     - Click "Edit the system environment variables"
     - Click "Environment Variables" button
     - Under "System variables", find "Path" → click Edit
     - Click "New" → type: C:\flutter\bin
     - Click OK on all dialogs
  5. Restart Command Prompt
  6. Verify: flutter --version

Mac:
  1. Go to: https://flutter.dev/docs/get-started/install/macos
  2. Download the SDK zip for your chip (Intel or Apple Silicon)
  3. Extract to ~/flutter
  4. Add to PATH in ~/.zshrc or ~/.bash_profile:
       export PATH="$PATH:$HOME/flutter/bin"
  5. Run: source ~/.zshrc
  6. Verify: flutter --version

STEP 2 — Install Android Studio
─────────────────────────────────
Flutter needs Android Studio to build and run Android apps.

  1. Download from: https://developer.android.com/studio
  2. Run the installer with default options
  3. When Android Studio opens, go to:
       More Actions → SDK Manager → SDK Tools tab
  4. Check: Android SDK Build-Tools, Android Emulator,
     Android SDK Platform-Tools
  5. Click Apply → OK

STEP 3 — Set up Android Emulator
──────────────────────────────────
In Android Studio:
  1. More Actions → Virtual Device Manager
  2. Click "Create Device"
  3. Choose: Pixel 6 (or any phone) → Next
  4. Choose system image: API 33 or 34 (Android 13/14) → Download if needed → Next
  5. Click Finish
  6. Click the ▶ Play button to start the emulator
  7. Wait for the emulator to fully boot (shows Android home screen)

STEP 4 — Run Flutter doctor
─────────────────────────────
This checks everything is set up correctly:

  flutter doctor

You should see checkmarks (✓) for:
  ✓ Flutter
  ✓ Android toolchain
  ✓ Android Studio
  ✓ Connected device (your emulator)

If you see ✗ marks, follow the suggested fixes shown.
Most common fix: run "flutter doctor --android-licenses" and accept all.

STEP 5 — Copy and set up the Flutter project
──────────────────────────────────────────────
  1. Copy the flutter_app/ folder from the ZIP to anywhere on your PC
     (e.g., Desktop\flutter_app)
  2. Open Command Prompt in that folder
  3. Install dependencies:
       flutter pub get

STEP 6 — Configure the API URL
────────────────────────────────
Open: lib/services/api_service.dart

Find this line at the top:
  static const String baseUrl = 'http://10.0.2.2:8000/api';

Use the correct URL for your setup:

  ANDROID EMULATOR (most common):
    http://10.0.2.2:8000/api
    (10.0.2.2 is how the emulator reaches your PC's localhost)

  REAL ANDROID DEVICE (plugged in via USB):
    http://YOUR_PC_IP:8000/api
    Find your PC's IP: open CMD → type ipconfig → look for IPv4 Address
    Example: http://192.168.1.15:8000/api

  iOS SIMULATOR (Mac only):
    http://localhost:8000/api

IMPORTANT: Your phone/emulator and PC must be on the SAME WiFi network
when using a real device!

STEP 7 — Also allow HTTP in Android (for localhost)
─────────────────────────────────────────────────────
Since localhost uses HTTP (not HTTPS), you need to allow it.
Open: android/app/src/main/AndroidManifest.xml

Find the <application tag and add:
  android:usesCleartextTraffic="true"

Example:
  <application
      android:usesCleartextTraffic="true"
      android:label="payroll_ph"
      ...>

STEP 8 — Run the app
──────────────────────
Make sure your emulator is running, then:

  flutter run

The app will compile (first time takes 2–3 minutes) and
launch on the emulator. You should see the PayrollPH login screen!

STEP 9 — Make sure Laravel is running too
───────────────────────────────────────────
The Flutter app won't work without the Laravel API running.
Keep the terminal with "php artisan serve" open the whole time.

═══════════════════════════════════════════════════════════
PART 3: DEFAULT ACCOUNTS
═══════════════════════════════════════════════════════════

After importing the SQL, these accounts exist by default:

  USERNAME                        PASSWORD    ROLE
  ──────────────────────────────────────────────────
  admin                           password    Admin
  manager1                        password    Manager
  juan.delacruz@company.com       password    Employee
  maria.santos@company.com        password    Employee
  jose.reyes@company.com          password    Employee
  ana.garcia@company.com          password    Employee
  carlos.mendoza@company.com      password    Employee
  luisa.torres@company.com        password    Employee
  roberto.flores@company.com      password    Employee
  carla.ramos@company.com         password    Employee

NOTE: Employee usernames are their work email addresses.
      All passwords are "password" (bcrypt hashed).

═══════════════════════════════════════════════════════════
PART 4: DEMO FLOW (for showing colleagues)
═══════════════════════════════════════════════════════════

Recommended order for a clean demo:

  1. Log in as admin / password
     → Show Dashboard with stats and pending requests badge

  2. Go to Employees → Add Employee
     → Notice the auto-generated account shown in the success message

  3. Go to Process Payroll → select a month → Preview
     → Show attendance-based proration (days present / working days)
     → Click Run Payroll

  4. Go to Payroll History
     → Show pagination, CSV Export, and Pay Rankings tab

  5. Go to Data Warehouse → Run ETL
     → Show fact table, data mart, quarterly view

  6. Log out → log in as juan.delacruz@company.com / password
     → Employee dashboard: net pay, attendance, benefits summary

  7. Go to My Benefits
     → Show full pay computation breakdown

  8. Go to My Requests → New Request → submit Leave - Sick

  9. Log out → log in as manager1 / password
     → Notice red badge on Requests tab
     → Approve the leave request

  10. Toggle ₱ / $ currency in the app bar
      → All amounts convert in real time

═══════════════════════════════════════════════════════════
PART 5: COMMON ERRORS AND FIXES
═══════════════════════════════════════════════════════════

ERROR: "Connection refused" in Flutter app
FIX: Make sure "php artisan serve" is still running in a
     terminal. The Laravel server must be running for
     the mobile app to work.

ERROR: "SQLSTATE[HY000] No connection" in Laravel
FIX: Check DB_PORT in .env matches your XAMPP MySQL port.
     If XAMPP uses 3307, set DB_PORT=3307

ERROR: "Class not found" for controllers
FIX: Run: php artisan optimize:clear
     Then: php artisan serve

ERROR: Flutter "Gradle build failed"
FIX: Open android/local.properties and verify:
     sdk.dir=C:\\Users\\YourName\\AppData\\Local\\Android\\Sdk

ERROR: Flutter app shows "Connection error. Is the server running?"
FIX 1: Check baseUrl in api_service.dart
FIX 2: Add android:usesCleartextTraffic="true" to AndroidManifest.xml
FIX 3: Check that your emulator and Laravel use the same network

ERROR: "419 CSRF token mismatch"
FIX: Make sure config/cors.php has 'supports_credentials' => false
     for mobile API use.

ERROR: "Unauthenticated" on all API calls after login
FIX: Check that your User model uses HasApiTokens trait.
     The model file is in: app/Models/User.php

ERROR: flutter doctor shows "Android licenses not accepted"
FIX: Run: flutter doctor --android-licenses
     Type 'y' and press Enter for each license.

═══════════════════════════════════════════════════════════
PART 6: VS CODE SETUP (recommended editor)
═══════════════════════════════════════════════════════════

Install these VS Code extensions for the best experience:

  For Laravel:
  - PHP Intelephense (by Ben Mewburn)
  - Laravel Extra Intellisense
  - PHP Debug (by Xdebug)

  For Flutter:
  - Flutter (by Dart Code) — REQUIRED
  - Dart (by Dart Code) — REQUIRED
  - Flutter Widget Snippets

After installing Flutter extension, VS Code can run and
debug the Flutter app directly without using Command Prompt.
Press F5 with an emulator running to launch the app.
