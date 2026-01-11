# GitHub Pages Setup Guide for StudyCoor

**Purpose:** Host privacy policy, terms of service, and support page for App Store submission

**Time Required:** 30-45 minutes (first time), 10 minutes (if familiar with GitHub Pages)

---

## Option 1: GitHub Pages (Recommended - FREE)

### Why GitHub Pages?

✅ **Free** - No hosting costs
✅ **Fast** - GitHub's CDN is fast worldwide
✅ **Simple** - No server management
✅ **Reliable** - 99.9% uptime
✅ **HTTPS** - Secure by default
✅ **Custom Domain** - Optional, but supported

### Step-by-Step Setup

#### Step 1: Create GitHub Repository

**Option A: Use This Repository**
```bash
# Already in your StudyCoor repo
cd /Users/owner/dev/StudyCoor

# Make sure you're on main branch
git checkout main
git pull
```

**Option B: Create Separate Docs Repository (Cleaner)**
```bash
# Create new repo for documentation only
# Go to https://github.com/new
# Name: studycoor-docs (or similar)
# Public repository (required for free GitHub Pages)
```

**Recommendation:** Use Option A (this repo) for simplicity.

---

#### Step 2: Create `docs` Directory

GitHub Pages can serve from `/docs` folder on main branch:

```bash
cd /Users/owner/dev/StudyCoor

# Create docs directory
mkdir -p docs

# We'll add files in next step
```

---

#### Step 3: Convert Markdown to HTML

GitHub Pages can serve markdown directly, but HTML gives more control.

**Option A: Simple Markdown (Easiest)**

Just copy the markdown files:
```bash
cp PRIVACY_POLICY.md docs/privacy.md
cp TERMS_OF_SERVICE.md docs/terms.md
```

GitHub Pages will render them automatically.

**Option B: HTML with Styling (Better Looking)**

Create styled HTML pages. I'll create these for you next.

---

#### Step 4: Create index.html (Support Page)

```bash
cat > docs/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>StudyCoor Support</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 40px auto;
            padding: 0 20px;
            color: #333;
        }
        h1 {
            color: #007AFF;
            border-bottom: 2px solid #007AFF;
            padding-bottom: 10px;
        }
        h2 {
            color: #555;
            margin-top: 30px;
        }
        a {
            color: #007AFF;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .footer {
            margin-top: 50px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            text-align: center;
            color: #777;
        }
    </style>
</head>
<body>
    <h1>StudyCoor Support</h1>

    <h2>About StudyCoor</h2>
    <p>StudyCoor is a professional pharmaceutical study coordination tool for iOS that helps calculate medication compliance, track subjects, and manage clinical study data.</p>

    <h2>Documentation</h2>
    <ul>
        <li><a href="privacy.html">Privacy Policy</a></li>
        <li><a href="terms.html">Terms of Service</a></li>
    </ul>

    <h2>Contact Support</h2>
    <p>For support inquiries, please contact:</p>
    <p><strong>Email:</strong> <a href="mailto:support@studycoor.com">support@studycoor.com</a></p>

    <h2>App Store</h2>
    <p><em>Coming soon to the iOS App Store</em></p>

    <div class="footer">
        <p>&copy; 2026 Brent Bloomquist. All rights reserved.</p>
        <p>StudyCoor &mdash; Professional Study Coordination</p>
    </div>
</body>
</html>
EOF
```

---

#### Step 5: Enable GitHub Pages

**Via GitHub Web Interface:**

1. Go to your repository on GitHub.com
2. Click **Settings** tab
3. Scroll to **Pages** section (left sidebar)
4. Under **Source**, select:
   - Branch: `main`
   - Folder: `/docs`
5. Click **Save**
6. Wait 1-2 minutes for deployment
7. Your site will be available at:
   ```
   https://[your-github-username].github.io/StudyCoor/
   ```

**Example URLs:**
- Privacy: `https://[username].github.io/StudyCoor/privacy.html`
- Terms: `https://[username].github.io/StudyCoor/terms.html`
- Support: `https://[username].github.io/StudyCoor/`

---

#### Step 6: Convert Privacy Policy to HTML

I'll create a properly formatted HTML version:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - StudyCoor</title>
    <!-- Add styles here -->
</head>
<body>
    <!-- Content from PRIVACY_POLICY.md -->
</body>
</html>
```

I'll create these files for you next.

---

#### Step 7: Test URLs

After GitHub Pages is enabled:

```bash
# Test your URLs
curl -I https://[username].github.io/StudyCoor/
curl -I https://[username].github.io/StudyCoor/privacy.html
curl -I https://[username].github.io/StudyCoor/terms.html
```

All should return `200 OK`.

---

#### Step 8: Update SettingsView.swift

Once URLs are live, update the app:

```swift
// Replace placeholder URLs with real ones
Link(destination: URL(string: "https://[username].github.io/StudyCoor/")!) {
    Label("Support Site", systemImage: "safari")
}
Link(destination: URL(string: "https://[username].github.io/StudyCoor/privacy.html")!) {
    Label("Privacy Policy", systemImage: "lock.shield")
}
Link(destination: URL(string: "https://[username].github.io/StudyCoor/terms.html")!) {
    Label("Terms of Service", systemImage: "doc.text")
}
```

---

## Option 2: Custom Domain (Optional)

### If You Own a Domain

**Example:** `studycoor.com` or `ios.studycoor.com`

#### Setup Steps:

1. **Buy domain** (if you don't have one):
   - Namecheap, Google Domains, Cloudflare: ~$10-15/year

2. **Configure DNS:**
   ```
   Type: CNAME
   Name: ios (or www)
   Value: [username].github.io
   ```

3. **Add Custom Domain in GitHub Pages:**
   - Settings > Pages > Custom domain
   - Enter: `ios.studycoor.com`
   - GitHub will verify and issue SSL certificate

4. **Update SettingsView.swift:**
   ```swift
   Link(destination: URL(string: "https://ios.studycoor.com/")!) { ... }
   Link(destination: URL(string: "https://ios.studycoor.com/privacy.html")!) { ... }
   Link(destination: URL(string: "https://ios.studycoor.com/terms.html")!) { ... }
   ```

**Cost:** $10-15/year (domain registration)
**Benefit:** Professional branded URLs

---

## Quick Start Commands

```bash
# 1. Create docs directory
mkdir -p docs

# 2. I'll create HTML files for you next

# 3. Commit and push
git add docs/
git commit -m "Add GitHub Pages documentation

- Privacy policy HTML
- Terms of service HTML
- Support page

Ready for GitHub Pages hosting.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push origin main

# 4. Enable GitHub Pages (web interface)
# Settings > Pages > Source: main branch, /docs folder

# 5. Wait 1-2 minutes, then test
# Visit: https://[username].github.io/StudyCoor/

# 6. Update SettingsView.swift with live URLs

# 7. Commit and push settings update
git add Views/SettingsView.swift
git commit -m "Update Settings with live GitHub Pages URLs"
git push origin main
```

---

## Troubleshooting

### Pages Not Loading?

**Check:**
1. ✅ Repository is public (required for free GitHub Pages)
2. ✅ Pages is enabled in Settings
3. ✅ Source is set to `main` branch, `/docs` folder
4. ✅ Files are in `/docs` directory (not root)
5. ✅ Waited 1-2 minutes for deployment
6. ✅ No typos in filenames (case-sensitive!)

### 404 Error?

- Check file paths: `privacy.html` not `privacy.md` (unless using markdown mode)
- GitHub Pages is case-sensitive
- Make sure files are pushed to GitHub

### SSL Certificate Error?

- Wait 5-10 minutes for automatic HTTPS provisioning
- GitHub Pages automatically issues SSL certificates

---

## File Structure

After setup, your repo should look like:

```
StudyCoor/
├── docs/
│   ├── index.html (support page)
│   ├── privacy.html (privacy policy)
│   ├── terms.html (terms of service)
│   └── style.css (optional shared styles)
├── Models/
├── Views/
│   └── SettingsView.swift (updated with live URLs)
├── PRIVACY_POLICY.md (source, keep for reference)
├── TERMS_OF_SERVICE.md (source, keep for reference)
└── ... (other files)
```

---

## Next Steps

1. ✅ Read this guide
2. 🔲 Create `docs` directory
3. 🔲 Let me create HTML files for you
4. 🔲 Commit and push to GitHub
5. 🔲 Enable GitHub Pages in Settings
6. 🔲 Test URLs
7. 🔲 Update SettingsView.swift
8. 🔲 Commit and push settings update
9. ✅ Phase 2 complete!

**Estimated Time:** 30-45 minutes total

---

## Pro Tips

### 1. Use GitHub Pages Automatic Markdown Rendering

Instead of converting to HTML, just use markdown:
- Save as `docs/privacy.md` and `docs/terms.md`
- GitHub Pages renders them automatically
- Looks clean with GitHub's default styling

### 2. Add Custom Favicon

```html
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📊</text></svg>">
```

### 3. Google Analytics (Optional)

Add tracking to see how many people view your privacy policy:
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
```

---

**Ready to proceed?** Let me know and I'll create the HTML files for you!
