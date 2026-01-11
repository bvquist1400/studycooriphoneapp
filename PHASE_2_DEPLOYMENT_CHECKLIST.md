# Phase 2: Hosting & URLs - Deployment Checklist

**Status:** Ready to Deploy
**Time Required:** 15-20 minutes
**Files Ready:** ✅ All GitHub Pages files committed

---

## Quick Start (3 Steps)

### Step 1: Push to GitHub (2 minutes)

```bash
# Make sure you're in the StudyCoor directory
cd /Users/owner/dev/StudyCoor

# Push all commits to GitHub
git push origin main
```

**Expected Output:**
```
Enumerating objects: XX, done.
Counting objects: 100% (XX/XX), done.
Delta compression using up to 8 threads
Compressing objects: 100% (XX/XX), done.
Writing objects: 100% (XX/XX), XXX.XX KiB | XXX.XX MiB/s, done.
Total XX (delta XX), reused 0 (delta 0), pack-reused 0
To github.com:[username]/StudyCoor.git
   XXXXXXX..ebc8c62  main -> main
```

---

### Step 2: Enable GitHub Pages (3-5 minutes)

1. **Go to your repository on GitHub.com**
   - Navigate to: `https://github.com/[your-username]/StudyCoor`

2. **Click "Settings" tab** (top right)

3. **Click "Pages"** in left sidebar (under "Code and automation")

4. **Configure Source:**
   - Branch: Select **`main`**
   - Folder: Select **`/ docs`**
   - Click **Save**

5. **Wait for deployment** (1-2 minutes)
   - GitHub will show: "Your site is live at https://[username].github.io/StudyCoor/"
   - Initially may show "Your site is ready to be published"
   - Refresh after 1-2 minutes

6. **Verify deployment**
   - Green checkmark appears when ready
   - URL shown at top of Pages settings

---

### Step 3: Test URLs (2 minutes)

Open these URLs in your browser:

1. **Support Page:**
   ```
   https://[your-username].github.io/StudyCoor/
   ```
   Should show: StudyCoor support page with navigation

2. **Privacy Policy:**
   ```
   https://[your-username].github.io/StudyCoor/privacy.html
   ```
   Should show: Complete privacy policy

3. **Terms of Service:**
   ```
   https://[your-username].github.io/StudyCoor/terms.html
   ```
   Should show: Complete terms of service

**All should load with proper styling and dark mode support.**

---

## Step 4: Update SettingsView (5 minutes)

### Find Your GitHub Username

If you don't know your GitHub username:
```bash
git remote -v
# Look for: https://github.com/[USERNAME]/StudyCoor.git
```

### Update URLs in Code

1. **Open** `Views/SettingsView.swift`

2. **Replace** placeholder URLs with your GitHub Pages URLs:

**Before:**
```swift
Link(destination: URL(string: "https://ios.studycoor.com/support")!) {
    Label("Support Site", systemImage: "safari")
}
Link(destination: URL(string: "https://ios.studycoor.com/privacy")!) {
    Label("Privacy Policy", systemImage: "lock.shield")
}
Link(destination: URL(string: "https://ios.studycoor.com/terms")!) {
    Label("Terms of Service", systemImage: "doc.text")
}
```

**After:**
```swift
Link(destination: URL(string: "https://[your-username].github.io/StudyCoor/")!) {
    Label("Support Site", systemImage: "safari")
}
Link(destination: URL(string: "https://[your-username].github.io/StudyCoor/privacy.html")!) {
    Label("Privacy Policy", systemImage: "lock.shield")
}
Link(destination: URL(string: "https://[your-username].github.io/StudyCoor/terms.html")!) {
    Label("Terms of Service", systemImage: "doc.text")
}
```

3. **Save** the file

4. **Commit** the update:
```bash
git add Views/SettingsView.swift
git commit -m "Update SettingsView with live GitHub Pages URLs

Replace placeholder URLs with live documentation:
- Support: https://[username].github.io/StudyCoor/
- Privacy: https://[username].github.io/StudyCoor/privacy.html
- Terms: https://[username].github.io/StudyCoor/terms.html

Phase 2: Hosting & URLs - COMPLETE ✅

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
git push origin main
```

---

## Step 5: Test in App (5 minutes)

1. **Build and run** StudyCoor on simulator or device:
   ```bash
   # In Xcode, press Cmd+R
   ```

2. **Navigate to Settings tab**

3. **Tap each link** and verify it opens in Safari:
   - [x] Support Site → Opens GitHub Pages support page
   - [x] Privacy Policy → Opens privacy.html
   - [x] Terms of Service → Opens terms.html

4. **Verify links work on device** (not just simulator)

---

## Troubleshooting

### GitHub Pages Not Enabling?

**Check:**
- ✅ Repository is **public** (required for free GitHub Pages)
- ✅ Commits are pushed to `main` branch
- ✅ `docs` folder exists in repository
- ✅ Selected `/docs` folder (not root)

### 404 Error When Opening Links?

**Common Causes:**
- Files not in `docs` folder
- Typo in filename (case-sensitive!)
- GitHub Pages not fully deployed yet (wait 2-3 minutes)
- Selected wrong branch or folder in Settings

**Fix:**
```bash
# Verify files are in docs folder
ls docs/
# Should show: index.html, privacy.html, style.css, terms.html

# Verify files are pushed
git status
# Should show: "Your branch is up to date with 'origin/main'"
```

### Links Don't Work in App?

**Check:**
- URL typos in SettingsView.swift
- Forgot to replace `[your-username]` with actual username
- URLs use `http://` instead of `https://` (GitHub Pages forces HTTPS)

---

## Verification Checklist

Before marking Phase 2 complete:

- [ ] Git commits pushed to GitHub
- [ ] GitHub Pages enabled in Settings
- [ ] Support page loads: `https://[username].github.io/StudyCoor/`
- [ ] Privacy policy loads: `https://[username].github.io/StudyCoor/privacy.html`
- [ ] Terms loads: `https://[username].github.io/StudyCoor/terms.html`
- [ ] SettingsView.swift updated with live URLs
- [ ] Settings update committed and pushed
- [ ] Tested links in Settings tab (simulator)
- [ ] Tested links in Settings tab (physical device)
- [ ] All links open correctly in Safari

---

## Optional: Custom Domain (Advanced)

### If You Want a Custom Domain

**Example:** `ios.studycoor.com` instead of GitHub Pages URL

**Steps:**

1. **Purchase domain** (~$10-15/year)
   - Namecheap, Google Domains, Cloudflare, etc.

2. **Add CNAME record** in DNS:
   ```
   Type: CNAME
   Name: ios (or subdomain you want)
   Value: [your-username].github.io
   TTL: 3600 (or automatic)
   ```

3. **Add custom domain in GitHub Pages:**
   - Settings > Pages > Custom domain
   - Enter: `ios.studycoor.com`
   - Check "Enforce HTTPS"
   - Save

4. **Wait for DNS propagation** (5-30 minutes)

5. **Update SettingsView.swift** with custom domain:
   ```swift
   Link(destination: URL(string: "https://ios.studycoor.com/")!) {
       Label("Support Site", systemImage: "safari")
   }
   Link(destination: URL(string: "https://ios.studycoor.com/privacy.html")!) {
       Label("Privacy Policy", systemImage: "lock.shield")
   }
   Link(destination: URL(string: "https://ios.studycoor.com/terms.html")!) {
       Label("Terms of Service", systemImage: "doc.text")
   }
   ```

**Benefits:**
- Professional branded URLs
- Easier to remember
- Better for marketing

**Cost:** $10-15/year

---

## Success Criteria

### Phase 2 is COMPLETE when:

✅ All 3 documentation pages are live on GitHub Pages
✅ SettingsView links point to live URLs
✅ Links tested and working in app
✅ Privacy policy accessible via App Store-required URL
✅ Terms of service accessible via URL

### Ready for Phase 3 when:

✅ Phase 2 checklist complete
✅ URLs confirmed working on physical device
✅ Documentation looks professional (no typos, proper formatting)

---

## What's Next: Phase 3 Preview

**App Store Connect Setup** (6-8 hours)

1. Create App Store Connect listing
2. Configure in-app purchases (pro.monthly, pro.yearly)
3. Upload app icon (1024x1024)
4. Add app description from APP_STORE_METADATA.md
5. Add keywords and screenshots requirements
6. Enter live privacy policy URL ← **You'll have this from Phase 2!**

See [APP_STORE_METADATA.md](APP_STORE_METADATA.md) for complete Phase 3 guide.

---

## Notes

### Email Address

You're using `support@studycoor.com` in the documentation. Make sure:
- This email exists and you can receive mail, OR
- Update all references to your actual support email

**Files to update if needed:**
- `docs/index.html` (line ~35)
- `docs/privacy.html` (line ~182)
- `docs/terms.html` (line ~187)
- `Views/SettingsView.swift` (line ~119)

### Repository Visibility

**Important:** Your repository must be **public** for free GitHub Pages.

If you need private repo:
- GitHub Pages requires GitHub Pro ($4/month)
- Alternative: Use Cloudflare Pages (free, supports private repos)

---

## Time Tracking

**Estimated Phase 2 Time:** 1 day (6-8 hours)
**Actual Time:** ~30-45 minutes (thanks to pre-prepared files!)

**Time Saved:** 5-7 hours by having documentation ready

---

**Phase 2 Status:** ✅ READY TO DEPLOY

Just follow Steps 1-5 above and you're done!

**Next Session:** Phase 3 - App Store Connect Setup

---

**Checklist Created:** January 11, 2026
**Instructions By:** Claude Code Analysis
