# Snapflow Admin Dashboard - Testing Guide

**Version:** 1.0  
**Last Updated:** January 12, 2025  
**Status:** Production Ready

---

## Table of Contents

1. [Authentication Testing](#authentication-testing)
2. [Dashboard Home Testing](#dashboard-home-testing)
3. [User Management Testing](#user-management-testing)
4. [Content Moderation Testing](#content-moderation-testing)
5. [Analytics Dashboard Testing](#analytics-dashboard-testing)
6. [Alerts Page Testing](#alerts-page-testing)
7. [Settings Page Testing](#settings-page-testing)
8. [Responsive Design Testing](#responsive-design-testing)
9. [Cross-Browser Testing](#cross-browser-testing)
10. [Performance Testing](#performance-testing)
11. [Security Testing](#security-testing)
12. [Error Handling Testing](#error-handling-testing)

---

## 1. Authentication Testing

### Test Cases

#### TC-AUTH-001: Valid Admin Login
- **Steps:**
  1. Navigate to login page
  2. Enter valid admin email and password
  3. Click "Sign In" button
- **Expected:** Redirect to dashboard home, display admin email in header

#### TC-AUTH-002: Non-Admin Login
- **Steps:**
  1. Navigate to login page
  2. Enter valid non-admin email and password
  3. Click "Sign In" button
- **Expected:** Display error message "Access denied. Admin privileges required."

#### TC-AUTH-003: Invalid Credentials
- **Steps:**
  1. Navigate to login page
  2. Enter invalid email/password
  3. Click "Sign In" button
- **Expected:** Display error message "Invalid email or password"

#### TC-AUTH-004: Session Persistence
- **Steps:**
  1. Login as admin
  2. Refresh page (F5)
- **Expected:** Remain logged in, dashboard displays correctly

#### TC-AUTH-005: Logout Functionality
- **Steps:**
  1. Login as admin
  2. Click profile dropdown
  3. Click "Sign out"
- **Expected:** Redirect to login page, session cleared

#### TC-AUTH-006: Protected Route Access
- **Steps:**
  1. Open browser in incognito mode
  2. Navigate directly to /dashboard
- **Expected:** Redirect to login page

---

## 2. Dashboard Home Testing

### Test Cases

#### TC-DASH-001: Stats Display
- **Steps:**
  1. Login as admin
  2. View dashboard home page
- **Expected:** 
  - Display 5 stat cards (Total Users, Total Videos, DAU, WAU, MAU)
  - All stats show numeric values
  - No loading skeletons visible

#### TC-DASH-002: Trend Indicators
- **Steps:**
  1. View each stat card
  2. Check trend indicator and percentage
- **Expected:**
  - Green up arrow for positive trends
  - Red down arrow for negative trends
  - Gray dash for zero change
  - Percentage displayed next to arrow

#### TC-DASH-003: Loading States
- **Steps:**
  1. Clear browser cache
  2. Login and navigate to dashboard
- **Expected:** Display 5 skeleton cards during initial load

#### TC-DASH-004: Real-Time Updates
- **Steps:**
  1. View dashboard home
  2. Wait 30 seconds
  3. Observe stats
- **Expected:** Stats automatically refresh without page reload

#### TC-DASH-005: Responsive Layout
- **Steps:**
  1. Resize browser window to mobile (375px)
  2. View dashboard home
- **Expected:** Stat cards stack vertically, remain readable

---

## 3. User Management Testing

### Test Cases

#### TC-USER-001: User List Display
- **Steps:**
  1. Navigate to /dashboard/users
  2. View user table
- **Expected:**
  - Display paginated user list (10 users per page)
  - Show columns: User, Email, Followers, Videos, Joined, Status, Actions
  - All data populated correctly

#### TC-USER-002: Search Functionality
- **Steps:**
  1. Enter username in search field
  2. Press Enter or click search icon
- **Expected:** Filter users by username (case-insensitive)

#### TC-USER-003: Sort Options
- **Steps:**
  1. Click sort dropdown
  2. Select "Newest"
- **Expected:** Users sorted by creation date (newest first)

#### TC-USER-004: Pagination
- **Steps:**
  1. Scroll to bottom of user list
  2. Click "Load More" button
- **Expected:** Load next 10 users, append to list

#### TC-USER-005: Ban User
- **Steps:**
  1. Click three-dot menu on user row
  2. Select "Ban User"
  3. Confirm action in dialog
- **Expected:**
  - Toast notification "User banned successfully"
  - Status badge changes to "Banned" (red)

#### TC-USER-006: Delete User
- **Steps:**
  1. Click three-dot menu on user row
  2. Select "Delete User"
  3. Confirm action in dialog
- **Expected:**
  - Toast notification "User deleted successfully"
  - User removed from list

#### TC-USER-007: Responsive Table
- **Steps:**
  1. Resize to mobile (375px)
  2. View user table
- **Expected:** Table scrolls horizontally, all columns visible

---

## 4. Content Moderation Testing

### Test Cases

#### TC-MOD-001: Flagged Videos Display
- **Steps:**
  1. Navigate to /dashboard/videos
  2. View video grid
- **Expected:**
  - Display flagged videos in 3-column grid (desktop)
  - Show thumbnail, title, owner, stats
  - Display "Flagged" badge

#### TC-MOD-002: Video Preview
- **Steps:**
  1. Click "Preview" button on video card
  2. View modal dialog
- **Expected:**
  - Modal opens with video player
  - Display video metadata (title, description, stats)
  - Video plays if HLS URL available

#### TC-MOD-003: Approve Video
- **Steps:**
  1. Click "Approve" button on video card
  2. Confirm action in dialog
- **Expected:**
  - Toast notification "Video approved successfully"
  - Video removed from moderation queue

#### TC-MOD-004: Remove Video
- **Steps:**
  1. Click "Remove" button on video card
  2. Confirm action in dialog
- **Expected:**
  - Toast notification "Video removed successfully"
  - Video removed from list

#### TC-MOD-005: Empty State
- **Steps:**
  1. View videos page when no flagged videos exist
- **Expected:** Display empty state with icon and message

#### TC-MOD-006: Real-Time Updates
- **Steps:**
  1. View videos page
  2. Wait 30 seconds
- **Expected:** List refreshes automatically

---

## 5. Analytics Dashboard Testing

### Test Cases

#### TC-ANAL-001: Charts Rendering
- **Steps:**
  1. Navigate to /dashboard/analytics
  2. View all charts
- **Expected:**
  - User Growth Chart (LineChart) renders
  - Video Uploads Chart (BarChart) renders
  - Retention Metrics Card (PieChart) renders
  - System Health Card displays

#### TC-ANAL-002: Date Range Selection
- **Steps:**
  1. Click "Last 7 Days" button
  2. Observe chart updates
- **Expected:** Charts filter data to last 7 days

#### TC-ANAL-003: Custom Date Range
- **Steps:**
  1. Click start date input
  2. Select start date
  3. Click end date input
  4. Select end date
- **Expected:** Charts filter to custom date range

#### TC-ANAL-004: Chart Interactivity
- **Steps:**
  1. Hover over chart data points
  2. View tooltips
- **Expected:** Display detailed information on hover

#### TC-ANAL-005: Responsive Charts
- **Steps:**
  1. Resize to tablet (768px)
  2. View analytics page
- **Expected:** Charts stack vertically, remain interactive

---

## 6. Alerts Page Testing

### Test Cases

#### TC-ALERT-001: Active Alerts Display
- **Steps:**
  1. Navigate to /dashboard/alerts
  2. View alerts list
- **Expected:** Display only unacknowledged alerts by default

#### TC-ALERT-002: All Alerts Toggle
- **Steps:**
  1. Toggle "All Alerts" switch
- **Expected:** Display both acknowledged and unacknowledged alerts

#### TC-ALERT-003: Severity Filtering
- **Steps:**
  1. Click "Critical" severity badge
- **Expected:** Filter alerts to show only Critical severity

#### TC-ALERT-004: Acknowledge Alert
- **Steps:**
  1. Click "Acknowledge" button on alert card
- **Expected:**
  - Toast notification "Alert acknowledged"
  - Alert displays checkmark badge
  - Acknowledge button disabled

#### TC-ALERT-005: Real-Time Updates
- **Steps:**
  1. View alerts page
  2. Wait 30 seconds
- **Expected:** Alerts list refreshes automatically

---

## 7. Settings Page Testing

### Test Cases

#### TC-SET-001: Profile Display
- **Steps:**
  1. Navigate to /dashboard/settings
  2. View admin profile section
- **Expected:**
  - Display admin email
  - Display user ID (Firebase UID)
  - Display "Administrator" badge

#### TC-SET-002: Sign Out
- **Steps:**
  1. Click "Sign Out" button
- **Expected:** Redirect to login page, session cleared

#### TC-SET-003: System Info
- **Steps:**
  1. View system information section
- **Expected:**
  - Display dashboard version
  - Display Firebase project ID
  - Display environment badge

---

## 8. Responsive Design Testing

### Device Breakpoints

| Device | Width | Test Focus |
|--------|-------|------------|
| Mobile | 375px | Single column, stacked layout |
| Mobile Large | 414px | Touch targets, readability |
| Tablet | 768px | Two-column layout, navigation |
| Desktop | 1366px | Multi-column, optimal spacing |
| Desktop Large | 1920px | Full feature display |

### Pages to Test

- [ ] Login page
- [ ] Dashboard home
- [ ] User management
- [ ] Content moderation
- [ ] Analytics dashboard
- [ ] Alerts page
- [ ] Settings page

### Responsive Checklist

- [ ] Sidebar collapses to hamburger menu on mobile
- [ ] Tables scroll horizontally on small screens
- [ ] Charts remain readable and interactive
- [ ] Cards stack vertically on mobile
- [ ] Text remains legible at all sizes
- [ ] Buttons are tappable (min 44x44px)
- [ ] No horizontal scrolling on mobile
- [ ] Images and videos scale appropriately

---

## 9. Cross-Browser Testing

### Browsers to Test

- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)

### Test Cases

- [ ] Login and authentication
- [ ] Dashboard navigation
- [ ] Chart rendering (Recharts)
- [ ] Form inputs and buttons
- [ ] Modal dialogs
- [ ] Toast notifications

---

## 10. Performance Testing

### Lighthouse Audit

Run Lighthouse audit in Chrome DevTools:
1. Open Chrome DevTools (F12)
2. Navigate to Lighthouse tab
3. Select "Desktop" mode
4. Click "Generate report"

**Target Metrics:**
- Performance: > 90
- Accessibility: > 95
- Best Practices: > 90
- SEO: > 80

### Performance Checklist

- [ ] Page load time < 3 seconds
- [ ] Time to Interactive < 3.8 seconds
- [ ] First Contentful Paint < 1.8 seconds
- [ ] Cumulative Layout Shift < 0.1
- [ ] Charts render smoothly (60fps)
- [ ] No memory leaks (check DevTools Memory tab)

---

## 11. Security Testing

### Security Checklist

- [ ] Environment variables not exposed in client code
- [ ] Firebase security rules enforce admin-only access
- [ ] API keys properly configured (NEXT_PUBLIC_ prefix)
- [ ] No sensitive data in logs or error messages
- [ ] Admin claim verification working correctly
- [ ] Protected routes properly guarded
- [ ] CORS policies appropriate
- [ ] XSS prevention (React escaping by default)

### Test Cases

#### TC-SEC-001: Non-Admin Access
- **Steps:**
  1. Create user without admin claim
  2. Attempt to login
- **Expected:** Access denied message

#### TC-SEC-002: Direct URL Access
- **Steps:**
  1. Logout
  2. Navigate directly to /dashboard/users
- **Expected:** Redirect to login page

#### TC-SEC-003: Token Expiration
- **Steps:**
  1. Login as admin
  2. Wait for token expiration (1 hour)
  3. Attempt to perform action
- **Expected:** Session refreshed or redirect to login

---

## 12. Error Handling Testing

### Test Cases

#### TC-ERR-001: Network Offline
- **Steps:**
  1. Open Chrome DevTools
  2. Go to Network tab
  3. Select "Offline" from throttling dropdown
  4. Attempt to load data
- **Expected:** Display error message, retry mechanism

#### TC-ERR-002: Slow Network
- **Steps:**
  1. Open Chrome DevTools
  2. Select "Slow 3G" throttling
  3. Load dashboard
- **Expected:** Display loading states, no timeouts

#### TC-ERR-003: Invalid Data
- **Steps:**
  1. Simulate malformed Firestore document
  2. Attempt to display data
- **Expected:** Graceful fallback, no crashes

#### TC-ERR-004: Empty States
- **Steps:**
  1. View page with no data (e.g., no flagged videos)
- **Expected:** Display empty state UI

---

## Testing Environment Setup

### Prerequisites

1. **Node.js 18+** installed
2. **Firebase project** with admin setup
3. **Admin user** with custom claim: `admin: true`
4. **Test data** in Firestore collections

### Environment Variables

Create `.env.local` file:

```env
NEXT_PUBLIC_FIREBASE_API_KEY=your_api_key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your_auth_domain
NEXT_PUBLIC_FIREBASE_PROJECT_ID=snapflow-4577d
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your_storage_bucket
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
NEXT_PUBLIC_FIREBASE_APP_ID=your_app_id
```

### Running Tests

```bash
# Development server
npm run dev

# Production build
npm run build
npm run start
```

---

## Test Execution Checklist

### Pre-Testing

- [ ] Environment variables configured
- [ ] Admin user created with custom claim
- [ ] Test data populated in Firestore
- [ ] Development server running
- [ ] Browser DevTools open

### During Testing

- [ ] Record all bugs found
- [ ] Screenshot any visual issues
- [ ] Note performance bottlenecks
- [ ] Document edge cases

### Post-Testing

- [ ] All critical bugs fixed
- [ ] Performance targets met
- [ ] Security checks passed
- [ ] Documentation updated

---

## Bug Reporting Template

```markdown
**Bug ID:** BUG-XXX
**Severity:** Critical / High / Medium / Low
**Module:** Dashboard / Users / Videos / Analytics / Alerts / Settings
**Browser:** Chrome / Firefox / Safari / Edge
**Device:** Desktop / Tablet / Mobile

**Steps to Reproduce:**
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Screenshots:**
Attach screenshots if applicable

**Console Errors:**
Copy any console errors

**Additional Notes:**
Any other relevant information
```

---

## Success Criteria

### Functional Requirements

- ✅ All authentication flows working
- ✅ All dashboard features functional
- ✅ Real-time updates working
- ✅ User management actions successful
- ✅ Content moderation working
- ✅ Analytics charts displaying correctly
- ✅ Alerts system functional
- ✅ Settings page complete

### Quality Metrics

- ✅ Zero critical bugs
- ✅ Performance score > 90
- ✅ Accessibility score > 95
- ✅ All browsers supported
- ✅ Responsive design working
- ✅ Security checks passed

---

**Document Status:** ✅ COMPLETE  
**Testing Status:** Ready for execution  
**Last Review:** January 12, 2025
