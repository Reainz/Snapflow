// Centralized admin allow-list and helper utils
// NOTE: For production, prefer loading these from Functions Config or Firestore.

export const ADMIN_EMAILS: string[] = [
  // 'admin@test.com',
  // 'teacher@example.com',
  'demo1@snapflow.test', // Added for k6 load testing
];

// Domain allow-list (lowercase; may optionally include leading '@')
export const ADMIN_DOMAINS: string[] = [
  'student.tdtu.edu.vn',
  'tdtu.edu.vn',
];

export type AdminAllowReason = 'email_allowlist' | 'domain_allowlist' | '';

export function checkAdminAllowed(emailRaw: string): { allowed: boolean; reason: AdminAllowReason } {
  const email = (emailRaw || '').toLowerCase();
  if (!email) return { allowed: false, reason: '' };

  // Priority 1: explicit email allow-list
  if (ADMIN_EMAILS.includes(email)) {
    return { allowed: true, reason: 'email_allowlist' };
  }

  // Priority 2: domain allow-list
  const rawDomain = email.split('@')[1]?.toLowerCase();
  const domain = rawDomain?.startsWith('@') ? rawDomain.slice(1) : rawDomain;
  const normalizedAllow = ADMIN_DOMAINS.map((d) => (d.startsWith('@') ? d.slice(1) : d));
  if (domain && normalizedAllow.includes(domain)) {
    return { allowed: true, reason: 'domain_allowlist' };
  }

  return { allowed: false, reason: '' };
}
