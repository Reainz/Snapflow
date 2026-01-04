export interface AdminConfig {
  emails: string[]; // Explicit email allow-list
  domains: string[]; // Trusted email domains
}
