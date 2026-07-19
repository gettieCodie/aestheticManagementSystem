LUXI MANAGEMENT — LOGIN CODE & DEMO ACCOUNTS
=============================================

WHERE THE LOGIN CODE LIVES
---------------------------
luxi_management/lib/features/auth/
  presentation/login_screen.dart   - The Sign In screen (UI). Has the
                                      Username/Password fields and a
                                      "Demo accounts" hint box at the bottom.
  state/auth_controller.dart       - The actual login logic. login(username,
                                      password) checks two lists:
                                        1) a small built-in list of demo
                                           accounts (hardcoded in this file)
                                        2) the live "users" collection in
                                           Firestore (accounts created via
                                           User Management)
  services/users_repository.dart   - Reads/writes the Firestore "users"
                                      collection (used by both User
                                      Management's list and login above).
  models/app_user.dart             - The AppUser model (fullName, username,
                                      email, password, role, branch).

Admin-only "User Management" page (where new accounts get created):
luxi_management/lib/features/admin/presentation/pages/user_management_page.dart


PASSWORD
--------
Admin keeps its original password:      admin123
Every staff account's password is:      staff123

(Earlier this file said admin's password was unified to "staff123" too —
that was reverted. Admin is admin123, everyone else is staff123.)

Any NEW account you create yourself via User Management uses whatever
password you type into that form's "Temporary password" field — it is not
forced to be admin123/staff123 (only the 13 built-in demo accounts below
are).


WHAT TO TYPE IN THE "USERNAME" FIELD
-------------------------------------
It depends on which account:

- The original 9 built-in accounts log in with a short first-name-style
  handle (all lowercase) — NOT an email, NOT the full name.
- 4 additional accounts (added on request, one per branch) log in with
  their FULL EMAIL ADDRESS as the username instead — these mirror the real
  staff docs already seeded into Firestore's "users" collection by
  luxi_appointment (same fullName/email/branch), so they double as proof
  that email-as-username sign-in works.

    Role   | Full name         | Username                        | Branch    | Password
    -------|-------------------|----------------------------------|-----------|----------
    Admin  | Owner Admin       | admin                            | (all)     | admin123
    Staff  | Angela Cruz       | angela                           | Laguna    | staff123
    Staff  | Elena Garcia      | elena                            | Laguna    | staff123
    Staff  | Isabel Fernandez  | isabel                           | Batangas  | staff123
    Staff  | Carmen Reyes      | carmen                           | Batangas  | staff123
    Staff  | Sofia Torres      | sofia                            | Lipa      | staff123
    Staff  | Liza Tan          | liza                             | Lipa      | staff123
    Staff  | Miguel Santos     | miguel                           | Pampanga  | staff123
    Staff  | Rafael Cruz       | rafael                           | Pampanga  | staff123
    Staff  | Angela Reyes      | angela.reyes@luxuriskin.ph        | Laguna    | staff123
    Staff  | Carlo Villanueva  | carlo.villanueva@luxuriskin.ph    | Lipa      | staff123
    Staff  | Diane Mercado     | diane.mercado@luxuriskin.ph       | Batangas  | staff123
    Staff  | Michael Torres    | michael.torres@luxuriskin.ph      | Pampanga  | staff123

Examples:
    Username: admin                          Password: admin123
    Username: angela                         Password: staff123
    Username: angela.reyes@luxuriskin.ph     Password: staff123

For accounts created later via User Management: that form also asks for a
"Username" field — whatever you type there (short handle or full email,
your choice) is what you log in with. The account's email shown in the
accounts table is auto-generated only when you typed a short handle
(e.g. "jane" becomes jane@luxuriskin.com); it doesn't affect login either
way — only the Username field matters for signing in.
