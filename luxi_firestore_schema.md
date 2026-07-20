# Luxi — Appointment Management System

A Flutter and Firebase-based appointment management system developed for **Luxuriskin Aesthetic Clinic**. The project serves as the first development phase of the complete clinic management system and focuses on streamlining appointment scheduling, customer management, Point-of-Sale (POS), and inventory operations through a centralized platform.

The system allows customers to conveniently book appointments while enabling staff and administrators to efficiently manage appointments, customer records, sales transactions, inventory, and clinic operations across multiple branches. It also provides a scalable foundation for future enhancements, including predictive analytics and AI-driven decision support.

## Key Modules

- Appointment Management
- Customer Management
- Point-of-Sale (POS)
- Inventory Management
- Product Management
- Branch Management
- Payment Management
- Package Management
- Sales Monitoring

## System Workflow

1. Customer books an appointment.
2. Staff reviews and confirms the booking.
3. Customer receives the appointment status.
4. Staff performs the treatment.
5. POS records the transaction.
6. Inventory is automatically updated after every completed transaction.
7. Sales and inventory summaries are updated for reporting.

# Luxi — Firestore Data Model

Complete collection reference for the Luxuriskin management system (Flutter +
Firebase). One Firebase project is shared by two apps: the **customer app**
(no login) and the **management app** (staff & admin, Firebase Auth).

## Conventions

- **IDs** are Firestore auto-generated document IDs (strings), unless noted.
- **Timestamps** use Firestore `Timestamp` (`createdAt`, `updatedAt`).
- **References vs copies:** Firestore has no joins. A document stores the
  referenced document's ID (e.g. `serviceId`) *and* copies the few fields it
  needs to display (e.g. `serviceName`, `servicePrice`). Copies are a snapshot
  in time — they intentionally do **not** change if the source later changes,
  which keeps historical bookings and sales accurate.
- **Money** is stored as a number (peso amount).

---

## users

Staff and admin accounts. The document ID is the Firebase Auth `uid`.

| Field      | Type      | Notes                                  |
|------------|-----------|----------------------------------------|
| fullName   | string    |                                        |
| email      | string    | matches the Auth account               |
| role       | string    | `staff` or `admin`                     |
| branchId   | string    | assigned branch (admins may span all)  |
| isActive   | boolean   | disable access without deleting        |
| createdAt  | timestamp |                                        |

> The customer app needs **no** users — it's unauthenticated.

---

## branches

Clinic locations. Configured by admin.

| Field    | Type    | Notes                                        |
|----------|---------|----------------------------------------------|
| name     | string  | e.g. "Laguna"                                |
| address  | string  |                                              |
| phone    | string  | optional                                     |
| capacity | number  | concurrent appointment slots (≈ staff/rooms, e.g. 2) |
| isActive | boolean |                                              |

---

## services

Bookable treatments. Configured by admin in **POS Configuration**.

| Field           | Type      | Notes                                       |
|-----------------|-----------|---------------------------------------------|
| name            | string    |                                             |
| category        | string    | for grouping in the UI                      |
| price           | number    | list price (may change over time)           |
| durationMinutes | number    |                                             |
| description     | string    |                                             |
| consumables     | array     | products auto-used per session (see below)  |
| isActive        | boolean   | retire without deleting history             |
| createdAt       | timestamp |                                             |
| updatedAt       | timestamp |                                             |

**Consumable (each element of `consumables`):**

| Field       | Type   | Notes                       |
|-------------|--------|-----------------------------|
| productId   | string | reference to a product      |
| productName | string | copied                      |
| quantity    | number | units used per session      |

> When a service/session is completed, its consumables are deducted from
> **stock** (with `stockMovements` entries) — this is how services draw down
> inventory automatically.

---

## products

Retail and consumable inventory items. Configured by admin in **Inventory
Management**. Per-branch quantities live in **stock** (below), not here.

| Field         | Type      | Notes                                       |
|---------------|-----------|---------------------------------------------|
| name          | string    |                                             |
| sku           | string    | e.g. `SKU-SUN-050`                          |
| category      | string    | e.g. Skincare, Treatment, Professional Use  |
| supplier      | string    | e.g. "BeautyCorp Inc."                       |
| price         | number    | selling price                               |
| cost          | number    | purchase cost (for inventory value/margin)  |
| unit          | string    | e.g. `pcs`, `bottles`, `liters`             |
| reorderLevel  | number    | low-stock threshold (the "Reorder at" line) |
| criticalLevel | number    | below this = Critical status                |
| isActive      | boolean   |                                             |
| createdAt     | timestamp |                                             |
| updatedAt     | timestamp |                                             |

> **Status** (In Stock / Low Stock / Critical / Out of Stock) is *derived*, not
> stored: compare the product's total across branches to `reorderLevel` and
> `criticalLevel`. **Total Inventory Value** = Σ(stock.quantity × product.cost).

---

## customers

Client records. A booking from the customer app either **matches an existing
customer by phone** (their history grows) or creates a new one. The full record
below is maintained by **staff** in the management app — no customer login.

| Field       | Type      | Notes                                           |
|-------------|-----------|-------------------------------------------------|
| clientId    | string    | human code, e.g. `LUX-2024-001`                 |
| fullName    | string    |                                                 |
| email       | string    |                                                 |
| phone       | string    | **natural key** used to match returning clients |
| facebook    | string    |                                                 |
| photoUrl    | string    | Firebase Storage URL, optional                  |
| memberSince | timestamp | first visit / record creation                   |
| totalVisits | number    | rollup, optional                                |
| totalSpent  | number    | rollup, optional                                |
| noShowCount | number    | missed appointments — powers no-show monitoring |
| lastVisitAt | timestamp | optional                                        |
| createdAt   | timestamp |                                                 |

---

## packages

A treatment package a client has purchased, created at POS. Either from a
**promo** template or a **custom** (aesthetician-priced) definition. Powers the
"Active Treatment Packages" card and drives auto-generated session appointments.

| Field               | Type      | Notes                                   |
|---------------------|-----------|-----------------------------------------|
| customerId          | string    | reference                               |
| source              | string    | `promo` or `custom`                     |
| promoId             | string    | reference to promoPackages (if promo)   |
| name                | string    | e.g. "Skin Rejuvenation Package"        |
| packageType         | string    | for custom packages (service type)      |
| totalSessions       | number    | e.g. 6                                  |
| completedSessions   | number    | starts at 0                             |
| totalPrice          | number    | package price                           |
| paidAmount          | number    | total paid so far (grows with payments) |
| remainingBalance    | number    | totalPrice − paidAmount                 |
| paymentStatus       | string    | `fullyPaid`/`installment`/`overdue`     |
| dueDate             | string    | `YYYY-MM-DD`, for overdue balances      |
| sessionIntervalDays | number    | days between sessions, e.g. 7           |
| startDate           | string    | `YYYY-MM-DD` — first session            |
| branchId            | string    | reference                               |
| createdByStaffId    | string    | staff who created it                    |
| notes               | string    | optional                                |
| status              | string    | `active`/`completed`/`cancelled`        |
| createdAt           | timestamp |                                         |
| updatedAt           | timestamp |                                         |

> The session dates are generated from `startDate` + `sessionIntervalDays`, and
> each becomes a **booking** (see below) tagged with this package's ID.

---

## promoPackages

Admin-configured catalog of fixed-price packages shown under "Promo Packages"
at POS.

| Field        | Type      | Notes                          |
|--------------|-----------|--------------------------------|
| name         | string    | e.g. "Get Slim Package"        |
| sessionCount | number    | e.g. 40                        |
| fixedPrice   | number    | e.g. 5999                      |
| category     | string    | optional grouping              |
| isActive     | boolean   | retire without deleting        |
| createdAt    | timestamp |                                |
| updatedAt    | timestamp |                                |

---

## sessions — merged into bookings

There is **no separate `sessions` collection**. A package's sessions are
`bookings` (tagged with `packageId` + `sessionNumber`), so the appointment
calendar and the client's Session Timeline read from the same place. When staff
complete a session, they fill in `productsUsed`, `notes`, and `progressPhotos`
on that booking, and increment the package's `completedSessions`.

---

## bookings

The appointment hub, and the **calendar** itself. A booking is either a walk-in
appointment (from the customer app) or one auto-generated session of a package.
When completed, staff record the treatment details on it — so a client's
"Session Timeline" is simply their completed package bookings.

| Field           | Type      | Notes                                       |
|-----------------|-----------|---------------------------------------------|
| customerId      | string    | reference                                   |
| customerName    | string    | copied for display                          |
| serviceId       | string    | reference                                   |
| serviceName     | string    | copied for display                          |
| servicePrice    | number    | copied snapshot (price at booking time)     |
| branchId        | string    | reference                                   |
| branchName      | string    | copied for display                          |
| appointmentDate | string    | `YYYY-MM-DD`                                 |
| appointmentTime | string    | `HH:mm`                                      |
| startAt         | timestamp | date+time combined — for conflict/overlap checks |
| durationMinutes | number    | copied from service — end = startAt + this  |
| status          | string    | `pending`/`confirmed`/`completed`/`cancelled`/`no_show` |
| assessedPrice   | number    | final price after assessment; null until set |
| assignedStaffId | string    | aesthetician handling it; null until set    |
| staffName       | string    | copied, once assigned                       |
| packageId       | string    | reference, if this is a package session     |
| sessionNumber   | number    | e.g. 4 (of the package), if applicable      |
| productsUsed    | array     | products applied during the session         |
| progressPhotos  | array     | Firebase Storage URLs (staff-only access)   |
| notes           | string    | optional staff notes                        |
| createdAt       | timestamp |                                             |
| updatedAt       | timestamp |                                             |

---

## sales

POS transactions — the rows in **Sales History**. Line items are embedded as an
array (a receipt has a small, bounded number of lines).

| Field         | Type      | Notes                                     |
|---------------|-----------|-------------------------------------------|
| branchId      | string    | reference                                 |
| branchName    | string    | copied                                    |
| staffId       | string    | who processed it                          |
| staffName     | string    | copied (e.g. "Angela Cruz")               |
| customerId    | string    | optional reference                        |
| customerName  | string    | optional copy                             |
| packageId     | string    | optional — if the sale is for a package   |
| bookingId     | string    | optional — if the sale settles a booking  |
| items         | array     | see line-item shape below                 |
| subtotal      | number    |                                           |
| discount      | number    | defaults 0                                |
| total         | number    | subtotal − discount (Total Amount)        |
| paidAmount    | number    | paid so far (grows with installments)     |
| balance       | number    | total − paidAmount                        |
| paymentStatus | string    | `fullyPaid`/`installment`/`overdue`       |
| paymentMethod | string    | `cash`/`card`/`gcash`/…                    |
| createdAt     | timestamp |                                           |

**Line item (each element of `items`):**

| Field     | Type   | Notes                          |
|-----------|--------|--------------------------------|
| type      | string | `service` or `product`         |
| refId     | string | serviceId or productId         |
| name      | string | copied                         |
| quantity  | number |                                |
| unitPrice | number | copied snapshot                |
| lineTotal | number | quantity × unitPrice           |

---

## stock

Current on-hand quantity of a product **at one branch**. Use the document ID
`{branchId}_{productId}` so each branch/product pair is unique.

| Field       | Type      | Notes                    |
|-------------|-----------|--------------------------|
| branchId       | string    | reference                        |
| productId      | string    | reference                        |
| productName    | string    | copied                           |
| quantity       | number    | current on-hand at this branch   |
| expirationDate | string    | `YYYY-MM-DD`, optional            |
| updatedAt      | timestamp |                                  |

> The "Branch Allocation" column (Laguna 40 · Lipa 30 · …) is just the `stock`
> documents for one product across every branch.

---

## stockMovements

Audit trail of every inventory change — the "why" behind each `stock` number.
Restocks add; sales and service consumables subtract; transfers move stock
between branches; adjustments correct.

| Field          | Type      | Notes                                        |
|----------------|-----------|----------------------------------------------|
| branchId       | string    | reference (the branch affected)              |
| productId      | string    | reference                                    |
| productName    | string    | copied                                       |
| type           | string    | `restock`/`sale`/`consumable`/`transfer`/`adjustment` |
| quantityChange | number    | `+` in, `−` out                              |
| balanceAfter   | number    | resulting quantity                           |
| fromBranchId   | string    | for transfers — source branch                |
| toBranchId     | string    | for transfers — destination branch           |
| refId          | string    | related saleId / bookingId, if any           |
| staffId        | string    | who made the change                          |
| createdAt      | timestamp |                                              |

---

## summaries

Pre-aggregated rollups so the admin dashboard is fast (Firestore can't cheaply
crunch raw sales). Updated as sales happen (client or Cloud Function). Document
ID e.g. `{branchId}_{YYYY-MM-DD}`.

| Field            | Type      | Notes                                |
|------------------|-----------|--------------------------------------|
| branchId         | string    | reference                            |
| date             | string    | `YYYY-MM-DD`                         |
| totalSales       | number    | day's revenue                        |
| transactionCount | number    |                                      |
| servicesRevenue  | number    |                                      |
| productsRevenue  | number    |                                      |
| updatedAt        | timestamp |                                      |

> For real forecasting/ML, export Firestore → BigQuery and train there; the
> `summaries` collection is enough to power charts and simple trend lines.

---

## payments

Each individual payment against a package/sale — this is what makes
**installments** and the "Total Paid" vs "Outstanding Balance" totals possible.
Every payment appends here and bumps the package/sale `paidAmount`.

| Field         | Type      | Notes                            |
|---------------|-----------|----------------------------------|
| packageId     | string    | reference (or `saleId`)          |
| customerId    | string    | reference                        |
| amount        | number    | this payment                     |
| paymentMethod | string    | `cash`/`gcash`/`card`            |
| staffId       | string    | who received it                  |
| branchId      | string    | reference                        |
| createdAt     | timestamp | payment date                     |

---

## settings

A single global-config document (doc ID `global`) edited in **POS
Configuration** and "synced to all branches."

| Field            | Type      | Notes                                    |
|------------------|-----------|------------------------------------------|
| promoDiscountRate| number    | percent, e.g. 10                         |
| paymentMethods   | array     | enabled methods, e.g. `["cash","gcash","card"]` |
| updatedAt        | timestamp |                                          |
| updatedByStaffId | string    | admin who last saved                     |

---

## Relationships at a glance

- **bookings** → customers, services, branches; optionally packages (package sessions)
- **packages** → customers, branches; optionally promoPackages
- **promoPackages** → standalone catalog
- **services** → products (via `consumables`)
- **sales** → branches, staff (users), optionally customers, bookings & packages; items → services/products
- **payments** → packages (or sales), customers, branches, staff
- **stock** → branches, products
- **stockMovements** → branches, products, optionally sales/bookings
- **summaries** → branches
- **settings** → single global document

## Access model (Firestore Security Rules — to implement later)

There are two authenticated roles (**owner and admin are the same role** —
`admin` — with full access). Staff are **locked to their own branch**.

- **Customer app (unauthenticated):** read `services`, `branches`; create
  `customers` and `bookings`. Nothing else.
- **Staff (auth, role=staff):** read/write `bookings`, `customers`, `packages`,
  `payments`, `sales`, `stock`, `stockMovements` **only where `branchId` equals
  their own `branchId`**; read `services`, `products`, `branches`,
  `promoPackages`, `settings`. They cannot see or touch other branches' data.
- **Admin / owner (auth, role=admin):** full read/write across **all branches**,
  including `services`, `products`, `promoPackages`, `branches`, `users`,
  `summaries`, and `settings`.

> Enforcement: each `users` document has a `branchId`. Security rules compare a
> document's `branchId` to the signed-in staff member's `branchId` and allow the
> write only if they match; admins skip that check.

## Create Package (POS) — one atomic batch

Pressing "Create Package" must write all of the following in a single Firestore
batch/transaction (all-or-nothing):

1. one **packages** document on the client's record;
2. **N bookings** — one per session, dated from `startDate` + `sessionIntervalDays`;
3. one **sales** document (the package + any aftercare products + payment);
4. one **payments** entry for the initial payment;
5. for each aftercare product: decrement **stock** and log a **stockMovements** entry;
6. (optional) update the client's rollups and the day's **summaries**.

## Complete a session — one atomic batch

When staff mark a package session done:

1. set the **booking** to `completed` and save `productsUsed`, `notes`, `progressPhotos`;
2. increment the package's `completedSessions`;
3. for each of the service's **consumables**: decrement **stock** + log a **stockMovements** (`type: consumable`).

## Record a payment — one atomic batch

1. add a **payments** entry;
2. increase the package/sale `paidAmount` and recompute `remainingBalance` + `paymentStatus`;
3. (optional) update the day's **summaries**.

## Process a sale (POS) — one atomic batch  *(inventory deduction per transaction)*

Every checkout runs as one transaction so stock and sales never drift apart:

1. create one **sales** document with its line items + one **payments** entry;
2. for each **product** line item: decrement that branch's **stock** and log a
   **stockMovements** (`type: sale`);
3. for each **service** line item: decrement its **consumables** from **stock**
   and log **stockMovements** (`type: consumable`);
4. (optional) update **summaries** and the customer's `totalSpent`.

> This is requirement #2 — the POS automatically deducts inventory on every
> transaction, atomically, so an oversell can never happen.

---

## Appointment automation rules

How requirement #1 is enforced. These are validation checks the app runs
*before* writing a booking (data to support them is already in the model).

**Conflict detection.** A slot's capacity is the branch's `capacity`. Before
creating a booking, count existing bookings at that branch whose
`[startAt, startAt+durationMinutes)` overlaps the requested window and whose
status isn't `cancelled`/`no_show`. If that count ≥ `capacity`, block it. Once a
staff member is assigned, the same overlap check per `assignedStaffId` prevents
double-booking one aesthetician.

**Duplicate booking warning.** Match the customer by `phone`. If they already
have a booking for the same `serviceId` on the same day (or an overlapping
time), warn the staff/customer before saving — a soft stop, not a hard block.

**No-show monitoring.** A missed appointment is set to status `no_show`, which
increments the customer's `noShowCount`. The staff/admin can list `no_show`
bookings and flag repeat offenders (e.g. require a deposit). 

**Digital customer records.** Covered by `customers` + their bookings, packages,
sessions, payments and progress photos — the full history, no paper.
