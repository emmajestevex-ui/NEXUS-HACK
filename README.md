# NEXUS HACK

Community app and publishing panel for announcements, tutorials, image galleries, official links, and editable categories/subcategories. The app displays community content only; it does not install files, modify games, or provide gameplay cheats.

## Supabase setup

1. Open the Supabase project SQL Editor and run `supabase/schema.sql`.
2. In Supabase Authentication, create the admin user with an email and password.
3. In the SQL Editor, replace `YOUR_ADMIN_EMAIL` in the commented admin insert at the end of the schema with that email, uncomment those three lines, and run them. Do not expose a service-role key in the app or website.
4. In Authentication URL settings, add the published GitHub Pages URL to the allowed redirect URLs if email login requires it.

The publishable key in the iOS app and admin panel is intended for clients; Row Level Security policies protect writes. Never put a Supabase secret/service-role key in client code.

## Admin panel

The panel lives in `admin/` and can be published from GitHub Actions using GitHub Pages. In the repository settings, enable Pages with **GitHub Actions** as its source. The workflow publishes the panel whenever `main` changes. Log in with the Supabase Auth admin created above. Categories support one nested level; categories are editable by name, SF Symbols icon, order, visibility, and parent. Posts can contain text and a PNG/JPG/WebP image up to 4 MB.

## iOS app

Open `NexusCommunity.xcodeproj` in Xcode on macOS. The GitHub Actions workflow also produces an **unsigned iOS Simulator app** artifact. That artifact is not an installable iPhone IPA. A device IPA requires macOS/Xcode and an Apple signing certificate and provisioning profile belonging to the app owner.

## Configuration

Supabase project URL and publishable key are in `NexusCommunity/AppConfig.swift` and `admin/app.js`. The Discord link is initially seeded in the database. Set TikTok from the admin panel when its exact profile URL is available.
