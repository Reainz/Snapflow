"use strict";
// Centralized admin allow-list and helper utils
// NOTE: For production, prefer loading these from Functions Config or Firestore.
Object.defineProperty(exports, "__esModule", { value: true });
exports.ADMIN_DOMAINS = exports.ADMIN_EMAILS = void 0;
exports.checkAdminAllowed = checkAdminAllowed;
exports.ADMIN_EMAILS = [
// 'admin@test.com',
// 'teacher@example.com',
];
// Domain allow-list (lowercase; may optionally include leading '@')
exports.ADMIN_DOMAINS = [
    'student.tdtu.edu.vn',
    'tdtu.edu.vn',
];
function checkAdminAllowed(emailRaw) {
    const email = (emailRaw || '').toLowerCase();
    if (!email)
        return { allowed: false, reason: '' };
    // Priority 1: explicit email allow-list
    if (exports.ADMIN_EMAILS.includes(email)) {
        return { allowed: true, reason: 'email_allowlist' };
    }
    // Priority 2: domain allow-list
    const rawDomain = email.split('@')[1]?.toLowerCase();
    const domain = rawDomain?.startsWith('@') ? rawDomain.slice(1) : rawDomain;
    const normalizedAllow = exports.ADMIN_DOMAINS.map((d) => (d.startsWith('@') ? d.slice(1) : d));
    if (domain && normalizedAllow.includes(domain)) {
        return { allowed: true, reason: 'domain_allowlist' };
    }
    return { allowed: false, reason: '' };
}
//# sourceMappingURL=allowlist.js.map