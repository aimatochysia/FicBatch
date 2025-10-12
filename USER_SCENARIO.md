# User Scenarios

---

## 1. First-Time App Launch & Onboarding

**Scenario:**  
A new user installs the app and opens it. A 3-step onboarding guide explains the app’s purpose and features. They're prompted to pick an empty folder to store downloaded works. The app requests storage permissions and confirms the folder is usable.

---

## 2. Adding Works via Home Tab (Pasted Links)

**Scenario:**  
User switches to the Home tab and pastes several AO3 work links (separated by spaces, commas, or newlines). The app parses the links, validates them, and adds valid ones to the default category in the library. If auto-download is enabled, the app begins downloading them (throttled). A toast shows results.

---

## 3. Browsing AO3 in Modified WebView (Browse Tab)

**Scenario:**  
User opens the Browse tab and sees a cleaner version of AO3. While reading a work, they tap "Add to Library", choose a category, and optionally download it. The work’s metadata and tags are extracted and stored. If the work already exists in that category, it’s skipped with a notice.

---

## 4. Viewing and Managing Library (Library Tab)

**Scenario:**  
User opens the Library tab to browse their saved works. They switch between grid and list view, sort works by title or last read, and filter using the search bar (by author, title, or tag). They long-press to select multiple works and:

- Move them to another category  
- Download them  
- Delete them  

User can manage categories (add, rename, delete). Duplicate titles within a category are not allowed.

---

## 5. Favoriting Works

**Scenario:**  
User taps a star icon to favorite a work. This visually highlights the work and allows sorting by “Favorites First.” Favoriting works also optionally pins them in library views (if enabled in settings).

---

## 6. Downloading Works (Single or Batch)

**Scenario:**  
User taps the download icon on one or more works. The app queues the download (with throttling) and saves the HTML to the selected folder. On success/failure, a snackbar/toast appears. Tags are parsed and stored from the downloaded HTML.

---

## 7. Syncing Works for Updates

**Scenario:**  
User taps "Sync Now" in the Updates tab or settings. The app checks each saved work’s AO3 metadata (especially lastUpdated) and compares it with:

- userAddedDate  
- lastSyncDate  
- downloadedAt  

If a newer version exists, the work is marked as updated and shown in the Updates tab. Sync is throttled to avoid overwhelming AO3.

---

## 8. Viewing Updated Works (Updates Tab)

**Scenario:**  
User opens the Updates tab to view a list of works that have changed since their last sync. These are grouped by update date and show which category each work belongs to. User can:

- Tap to re-download a work  
- Multi-select to download updates in bulk  
- See when last sync happened  
- Mark as ignored (optional)  

---

## 9. Reading a Work (Online or Offline)

**Scenario:**  
User opens a work from their library. If downloaded, the offline HTML is loaded into a customized webview with font and layout settings. If offline file is missing or corrupted, the app shows a toast and loads the online version instead.

While reading, the app tracks:

- Chapter being read (via anchors or chapter titles)  
- Scroll position  
- Time of reading  

This info is saved to be used in history or resume later.

---

## 10. Viewing Reading and Download History

**Scenario:**  
User opens the History tab to see:

- Recently read works with timestamps  
- Which chapter they reached  
- Downloaded works with dates  

They can tap any item to resume reading from where they left off.

---

## 11. Exporting Library Data

**Scenario:**  
User goes to Settings → Data → Export Library. They choose a location to save a JSON file containing:

- Work metadata  
- Tags  
- Categories  
- Favorite status  
- Read progress  
- Sync/download timestamps  

---

## 12. Importing Library Data

**Scenario:**  
User opens Settings → Data → Import Library. They select a valid JSON file. The app parses and shows a summary of:

- New works added  
- Duplicates skipped  
- Conflicts resolved  

Works are restored with their metadata, tags, categories, and reading progress intact.

---

## 13. Changing App Settings

**Scenario:**  
User opens the Settings tab and navigates categorized sections:

- **General**  
  - Dark Mode (System / Light / Dark)  
  - Grid or List view toggle  
  - Default sorting option  
  - Font family and size for app UI  

- **Reader**  
  - Font size  
  - Line height  
  - Reading theme (light/dark/sepia)  
  - Chapter jump setting (enable/disable)  

- **Downloads**  
  - Auto-download toggle  
  - Throttle delay selector  
  - Re-pick folder  
  - Clear all downloads  

- **Data**  
  - Import/export JSON  
  - Reset app data  
  - Clear reading/download history  

---

## 14. Re-picking Download Folder

**Scenario:**  
User opens Settings → Downloads → Re-pick Folder. They’re prompted to select a new empty directory. App verifies and migrates references accordingly. If folder is deleted or permission lost, app prompts again.

---

## 15. Handling File Errors & Fallbacks

**Scenario:**  
User tries to open a downloaded work, but the file is missing or corrupted. The app:

- Shows a small toast:  
  “Offline file missing. Switching to online view.”  
- Loads the AO3 web version inside the reader  
- No crashes or blockers occur.

---

## 16. Automatic Reading Progress Tracking

**Scenario:**  
User reads a long AO3 work with multiple chapters. Whether online or offline, the app records:

- Which chapter or section was last read  
- Timestamp  
- Scroll position  

When user opens the work again, they are asked:

- “Resume from Chapter 6?”  
or automatically scrolled to where they left off.

---

## 17. Preventing Duplicates in Categories

**Scenario:**  
User tries to add the same work to a category where it already exists. The app shows a small popup:

- “This work is already in that category.”  

No duplication is allowed within the same category, but the same work can exist in different categories (if allowed in future).

---
