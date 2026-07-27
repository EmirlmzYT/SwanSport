# 💳 SWANSPORT — SCREEN 14 PRODUCT SPECIFICATION
## Financial Management, Billing & Club Accounting Center

---

## 1. Executive Summary

Screen 14 (Financial Management, Billing & Club Accounting Center) is the enterprise financial operations, fee billing, debt collection, expense governance, and accounting control hub of the SwanSport platform. Functioning as a centralized multi-tenant financial management engine, Screen 14 governs the end-to-end fiscal health of sports clubs, academies, branches, facilities, and teams.

The primary objective of Screen 14 is to establish complete financial clarity, eliminate revenue leakage, automate member billing lifecycles, and enforce strict fiscal governance across all sports operations. By unifying membership fee plans, parent/payer accounts, installment schedules, discount/scholarship approvals, expense tracking, cost center allocations, cash/bank reconciliation, and financial audit trails, Screen 14 enables club leadership, financial managers, branch administrators, and families to interact in a transparent, privacy-aware financial ecosystem.

---

## 2. Product Vision

Screen 14 elevates sports club administration from informal payment tracking into an enterprise-grade financial management center. It operates as the ultimate source of truth for all financial transactions, charges, receivables, expenses, and cash positions within the SwanSport platform.

### Conceptual Inter-Module Integration
Screen 14 consumes operational context read-only across all frozen platform modules (Screens 1–13):
- **Screen 2 (Dashboard):** Feeds high-level financial health indicators, collection rates, and net cash positions into executive summary widgets.
- **Screen 3 (Athlete Management):** Consumes athlete registration states, active rosters, and branch/team assignments to drive automated fee plan assignments.
- **Screen 4 & Screen 6 (Team & Calendar):** References team enrollments and seasonal session schedules to validate fee eligibility and billable training packages.
- **Screen 5 (Training & Match Scheduling):** Contextualizes fee-based training camps, special competition entries, and event-based charges.
- **Screen 7 (Communication Center):** Dispatches automated billing statements, payment reminders, overdue notices, and receipt confirmations.
- **Screen 8 (Documents & File Center):** Links signed financial agreements, membership contracts, scholarship forms, and expense proof attachments.
- **Screen 9 & Screen 10 (Administration & Club Configuration):** Consumes enterprise tax structures, financial approval limits, and multi-branch organizational policies.
- **Screen 11 (Facility Management):** Receives facility usage hours, zone rental reservations, and maintenance activity data to generate facility revenue and cost allocations.
- **Screen 12 (Medical Center):** References medical clearance status to evaluate refund or fee-pause eligibility during prolonged injury rehabilitation.
- **Screen 13 (Reports & BI):** Exposes financial operational data for multi-variable enterprise business intelligence, trend analysis, and board reporting.

---

## 3. Executive Financial Dashboard

The Executive Financial Dashboard provides club owners, presidents, board members, club administrators, and financial managers with a real-time, comprehensive view of organizational fiscal health.

### High-Level Financial KPI Indicators
- **Total Expected Revenue:** Total billed and anticipated revenue for the active accounting period.
- **Total Collected Revenue:** Realized cash inflows collected across all payment channels.
- **Outstanding Receivables:** Billed amounts currently pending collection within standard credit terms.
- **Overdue Debt:** Total delinquent balances past due dates across all member and parent accounts.
- **Collection Rate (%):** Ratio of collected revenue against total expected revenue for the period.
- **Current Month Revenue & Expenses:** Realized revenue vs. total incurred expenses for the active month.
- **Net Cash Position & Available Cash:** Total liquid cash across all bank accounts and cash boxes minus immediate short-term obligations.
- **Bank Balance & Petty Cash:** Live balances across verified financial accounts.
- **Budget Utilization (%):** Percentage of allocated operational budget consumed across branches and cost centers.
- **Branch Profitability:** Comparative net earnings breakdown across physical campuses and sports branches.
- **Facility Revenue:** Total income generated from internal facility allocations and external rental bookings.
- **Active Installment Plans:** Count and total value of structured payment plans currently active.
- **Pending Refunds & Approvals:** Actionable count and monetary value of unapproved refunds, discounts, and high-value expenses.
- **Financial Compliance Alerts:** Active count of audit exceptions, unallocated payments, or threshold breaches.
- **Club Financial Health Score:** A composite 0–100 fiscal rating derived from collection efficiency, budget adherence, cash reserves, and debt risk.

### Trend & Risk Highlight Engine
- **Positive Trends:** Highlights financial improvements (e.g., "Monthly collection rate increased by +6.5%").
- **Negative Trends & Risks:** Flags financial risks (e.g., "Overdue debt in U18 Football increased by 12%").
- **High-Expense & Overrun Warnings:** Identifies cost centers exceeding budgeted thresholds (e.g., "Facility maintenance expenses 15% over budget").
- **Unusual Payment Activity:** Highlights unusual cash transactions, sudden spikes in discounts, or unallocated bank transfers.

---

## 4. Financial Command Center

The Financial Command Center serves as an operational queue prioritizing urgent financial tasks and fiscal risks requiring immediate action.

### Command Center Action Items
- **Receivables Requiring Action:** Large unpaid balances nearing critical credit thresholds.
- **Unpaid Athlete Balances:** Itemized list of active athletes with past-due tuition or competition fees.
- **Overdue Installment Plans:** Installment schedules with missed scheduled payment dates.
- **Failed Payment Attempts:** Transaction logs requiring follow-up or payment method updating.
- **Pending Refunds:** Refund requests submitted by parents or managers awaiting manager approval.
- **Unapproved Expenses:** Submitted expense claims awaiting budget owner sign-off.
- **Expiring Financial Contracts:** Sponsorships, vendor agreements, or scholarship terms ending within 30 days.
- **Unresolved Reconciliation Differences:** Bank transfer receipts that do not match open invoices.
- **Budget Threshold Warnings:** Cost centers reaching 90%+ of their seasonal budget allocation.
- **Low Cash Alerts:** Accounts falling below minimum operating reserve thresholds.
- **Branch Financial Risks:** Campuses experiencing severe collection drops or unexpected expense surges.

### Item Structure & Attributes
Each item displays: Severity Level (`Critical`, `Warning`, `Information`), Affected Entity (Athlete, Parent, Branch, Facility, Account), Monetary Amount, Due Date, Cause Explanation, Assigned Owner, Recommended Safe Action, and a direct navigation link to the financial record.

---

## 5. Member and Athlete Account Center

The Member and Athlete Account Center maintains a complete financial ledger for every individual athlete enrolled in the platform.

### Athlete Financial Profile Attributes
- **Athlete Identity & Payer Linkage:** Athlete name, unique ID, assigned branch, team, and primary linked payer/parent account.
- **Membership & Fee Plan Assignment:** Active fee plan, billing frequency (Monthly, Seasonal, Annual), and contract start/end dates.
- **Current Financial Status:** Real-time summary displaying Current Balance, Overdue Balance, Upcoming Charges, and Total Paid to Date.
- **Transaction History:** Chronological ledger detailing every issued charge, received payment, applied discount, scholarship credit, and approved refund.
- **Active Installment Schedule:** Details of active structured payment plans including next due date and remaining balance.
- **Financial Documents & Attachments:** Linked payment commitments, signed fee agreements, and proof-of-payment receipts.
- **Communication Log:** Record of billing statements sent, automated payment reminders dispatched, and payment promises logged.
- **Financial Risk Tag:** Risk classification (`Good Standing`, `Payment Due`, `Overdue - Grace Period`, `High Financial Risk`, `Suspended for Non-Payment`).

---

## 6. Parent and Payer Account Center

The Parent and Payer Account Center manages multi-athlete household accounts, corporate sponsors, and third-party institutional payers.

### Payer Account Functionality
- **Multi-Athlete Family Ledger:** Consolidated view grouping all children/dependents under a single primary payer (e.g., Parent/Guardian).
- **Sponsor & Corporate Payer Accounts:** Profiles for external institutions, foundations, or corporate sponsors subsidizing multiple athletes.
- **Consolidated Billing & Statements:** Ability to issue single combined family statements or individual itemized statements per child.
- **Payment Distribution:** Automated or manual allocation of single family payments across multiple children's outstanding charges.
- **Sponsor Contribution Tracking:** Ledger tracking portion of fees covered by sponsors vs. remaining parent responsibility.
- **Communication & Preference Center:** Billing notification settings, preferred receipt channels, and recorded financial notes.

---

## 7. Membership Fee Plans

Membership Fee Plans provide a flexible, rule-based structure for defining tuition, membership fees, and recurring charges.

### Scope & Structure Parameters
Fee plans can be scoped by Branch, Sport Discipline, Team Level, Age Group, Season, Athlete Category (Elite, Recreational, Academy), Facility Access Level, or Custom Individual Contract.

### Plan Component Types
- **Recurring Membership Fees:** Monthly, quarterly, seasonal, or annual tuition fees.
- **One-Time Onboarding Fees:** Registration fees, administrative setup fees, initial kit/uniform fees.
- **Special Operational Fees:** Competition entry fees, travel/accommodation fees, license fees, facility pass fees.

### Plan Attributes & Rules
Each fee plan defines: Title, Description, Target Scope, Billing Frequency, Default Amount, Applicable Tax/Fee Rules, Effective Start/Expiration Dates, Grace Period (days before late penalties apply), Late Payment Rules, and Active/Inactive State toggle.

---

## 8. Billing and Charge Management

The Billing and Charge Management module governs the generation, adjustment, and state management of financial charges.

### Charge Generation Workflows
- **Automated Periodic Billing:** Concept for scheduled batch billing based on assigned membership fee plans.
- **Manual & One-Time Charges:** Individual charges applied for ad-hoc events, custom gear, or specialized training camps.
- **Batch Charges:** Multi-athlete charge generation applied to an entire team, age group, or branch.
- **Charge Adjustments & Corrections:** Reversals, price corrections, and application of credit balances prior to invoice finalization.

### Charge Status Taxonomy & Product Behavior

| Status | Definition & Product Behavior |
| :--- | :--- |
| **Draft** | Charge created but not finalized. Editable; invisible to parents/athletes. |
| **Scheduled** | Pending automatic issuance on a designated future billing date. |
| **Issued** | Finalized charge published to payer account. Triggers statement dispatch; balance becomes payable. |
| **Partially Paid** | Payment received covering a portion of the charge total. Outstanding balance remains active. |
| **Paid** | Charge fully satisfied. Account balance updated; tax/receipt generation unlocked. |
| **Overdue** | Unpaid charge past due date and grace period. Triggers debt tracking and automated reminders. |
| **Cancelled** | Voided charge due to billing error or enrollment cancellation. Reverses balance without refund. |
| **Refunded** | Fully or partially returned funds following an approved refund workflow. |
| **Written Off** | Uncollectible charge marked as bad debt by authorized management. Clears receivable balance. |

---

## 9. Invoice and Statement Center

The Invoice and Statement Center manages formal financial records and account statements generated for payers and internal audit.

### Document Attributes & Contents
Every invoice/statement record contains: Unique Sequential Document Number, Payer Identity, Athlete/Beneficiary Name, Billing Period, Issue Date, Due Date, Itemized Line Items (Description, Quantity, Unit Price, Subtotal), Applied Discounts/Scholarships, Total Payable Amount, Total Paid Amount, Remaining Balance, Payment Status Badge, Payment Instructions, Notes, and Linked Contract References.

### Actions & Lifecycle
Authorized roles can View, Print, Export (PDF/Excel), Send/Resend via email/SMS, Cancel (Void), Correct, Duplicate, Issue Credit Notes, and Generate Account Statements over custom date ranges.

---

## 10. Payment Collection Center

The Payment Collection Center records, categorizes, and processes incoming cash flows across all accepted collection channels.

### Accepted Payment Method Categories
Cash Payments (Petty Cash/Branch Box), Bank Wire Transfers, Credit/Debit Card Transactions (Online/POS), Standing Orders/Direct Debits, Sponsor Direct Payments, Institutional Subsidies, Account Credit Balance Applications, and Split/Mixed Payments (e.g., Cash + Credit Balance).

### Payment Record Attributes
Each recorded payment includes: Payer Name, Linked Athlete/Account, Amount Collected, Currency, Date & Timestamp, Payment Method, Receiving Staff Member, Receiving Branch, Linked Invoice/Charge ID, External Reference Number, Official Receipt ID, Notes, and Processing Status.

### Payment Status Taxonomy
- **Pending:** Payment recorded but awaiting bank clearing or verification.
- **Completed:** Fully verified and applied payment.
- **Failed:** Rejected transaction (e.g., insufficient funds, card declined).
- **Cancelled:** Voided prior to settlement.
- **Reversed:** Refunded or chargeback-reversed payment.
- **Partially Applied:** Payment amount allocated to some but not all selected line items.
- **Unmatched:** Received payment lacking clear payer or invoice identification.

### Advanced Collection Operations
Supports Single Payments, Batch Payment Entry, Partial Payments, Overpayments (automatically held as positive Account Credit), Split Allocations across multiple invoices, Payment Reversals, Automated Receipt Generation, and Duplicate Payment Warning dialogs.

---

## 11. Installment Plan Management

Installment Plan Management allows clubs to break large annual or seasonal tuition fees into structured payment schedules for families.

### Plan Configuration Features
- Flexible schedule creation: Equal monthly installments, seasonal milestone payments, or custom due-date schedules.
- Down payment requirements: Mandatory initial deposit upon enrollment.
- Restructuring & Rescheduling: Ability to grant grace period extensions or adjust future installment due dates with approval.

### Installment Plan Indicators
Each plan tracks: Total Original Fee, Total Paid to Date, Remaining Balance, Total Number of Installments, Next Installment Due Date, Overdue Installments Count, Completion Percentage (%), and Plan Status (`Active`, `Completed`, `Overdue`, `Restructured`, `Cancelled`, `Defaulted`).

---

## 12. Debt and Overdue Management

The Debt and Overdue Management center isolates delinquent accounts and provides structured collection workflows.

### Debt Metrics & Risk Categorization
- Aging Analysis Buckets: `Current`, `1–7 Days Overdue`, `8–30 Days Overdue`, `31–60 Days Overdue`, `61–90 Days Overdue`, `90+ Days Overdue`.
- Risk Scoring Factors: Days overdue, number of missed installments, total family debt balance, and payment promise history.

### Safe Collection Actions
- Dispatch polite automated payment reminders via SMS, email, or push notifications.
- Log manual contact notes (e.g., "Parent called; promised payment by Friday").
- Create formal "Payment Promise" records with grace period holds.
- Offer approved installment restructuring or hardship discount applications.
- Escalate high-risk accounts to the Financial Manager for review.
- Place accounts on "Medical/Administrative Hold" restricting match participation in Screen 3 & Screen 5.

---

## 13. Discounts, Scholarships and Sponsorships

This module governs price reductions, merit scholarships, financial aid, and external sponsor contributions.

### Supported Discount & Assistance Types
- **Family & Staff Discounts:** Sibling discounts (e.g., 10% off second child), employee/coach child discounts.
- **Promotional & Early Payment:** Early bird registration discounts, full-season upfront payment discounts.
- **Financial Aid & Hardship:** Need-based tuition assistance, hardship waivers.
- **Merit & Athletic Scholarships:** Elite athlete grants funded by the club or sports ministry.
- **Sponsor-Funded Subsidies:** Corporate sponsor contributions linked to specific teams or athletes.

### Application & Guardrail Rules
Each discount record details: Discount Type, Value (Percentage % or Fixed Amount), Target Scope, Recipient Payer/Athlete, Effective Duration, Funding Source, Approval Reference, and Documentation Attachments. System guardrails enforce maximum combined discount limits (e.g., "Total combined discounts cannot exceed 40% of standard fee without Board Approval").

---

## 14. Refund and Credit Management

Refund and Credit Management controls the processing of returned funds, credit notes, and account transfers.

### Supported Refund Workflows
- **Full Refund:** Complete return of paid funds due to program cancellation or medical withdrawal.
- **Partial Refund:** Pro-rated return for partial attendance or mid-season departure.
- **Payment Reversal & Charge Voiding:** Nullifying mistaken billing entries.
- **Account Credit Application:** Converting refundable funds into a credit balance for future tuition instead of cash payout.
- **Inter-Sibling Credit Transfer:** Transferring positive credit balance between linked children within the same parent account.

### Approval Hierarchy
Low-value refunds ($< \$100$) can be processed by Branch Administrators. High-value refunds require multi-level approval from the Financial Manager or Club President.

---

## 15. Expense Management

Expense Management tracks all operational outflows, vendor invoices, staff reimbursements, and facility costs.

### Supported Expense Categories
Facility Rent, Utility Bills, Maintenance & Repairs, Sports Equipment Purchase, Coaching & Staff Remuneration, Transportation & Travel, Accommodation, Competition Entry Fees, Federation Registration Fees, Medical Supplies, Administrative & Office Expenses, Marketing & Communications, Insurance Policies, Taxes & Official Fees, and Miscellaneous Expenses.

### Expense Record & Lifecycle
Each expense records: Category, Monetary Amount, Currency, Incurred Date, Vendor/Payee Name, Branch Assignment, Team/Facility Allocation, Cost Center Code, Source Payment Account, Responsible User, Document/Receipt Attachment, Description, and Approval Status (`Draft`, `Submitted`, `Approved`, `Rejected`, `Paid`, `Cancelled`).

---

## 16. Budget Management

Budget Management enables fiscal planning, commitment tracking, and budget utilization monitoring across the organization.

### Budget Scope & Allocation
Budgets can be established for the entire club, specific branches, individual sports, teams, facility zones, departments, or special events.

### Budget Metrics
- **Planned Budget:** Approved seasonal budget allocation.
- **Revised Budget:** Adjusted budget following mid-season review.
- **Actual Spent:** Total paid expenses charged against the budget.
- **Committed Amount:** Approved purchase orders or upcoming contractual obligations not yet paid.
- **Remaining Budget:** Available funds remaining.
- **Variance (%):** Percentage deviation between actual spending and planned budget.

System alerts trigger automatically when budget utilization reaches $80\%$ and $95\%$ of allocated limits.

---

## 17. Cost Center Management

Cost Center Management allows multi-dimensional financial tracking by attributing revenues and expenses to specific operational units.

### Allocation Dimensions
Transactions can be allocated to Branches, Sports Disciplines, Specific Squads, Physical Facilities/Zones, Departments, Special Events, or Marketing Campaigns.

### Multi-Allocation Rules
Single transactions can be split across multiple cost centers using fixed percentage splits (e.g., 60% Main Campus / 40% North Branch) or explicit monetary amounts. Unassigned transactions generate audit warnings in the Financial Command Center.

---

## 18. Facility Financials

Facility Financials integrates with Screen 11 (Facility Management) to monitor revenue generation and operational costs associated with physical assets.

### Financial Dimensions
- **Facility Revenue:** Track internal program room allocations, external court/field rentals, and event bookings.
- **Facility Operational Costs:** Monitor utility consumption costs, janitorial/maintenance expenses, equipment depreciation, and facility lease payments.
- **Facility Profitability Metrics:** Net facility income, revenue per available usage hour, and cost per operational hour.

---

## 19. Team and Branch Financials

Team and Branch Financials provides localized profit-and-loss views for individual campuses, sports branches, and athletic squads.

### Comparative Financial Metrics
- Branch/Team Expected Revenue vs. Collected Revenue.
- Total Branch Expenses and Budget Utilization %.
- Net Financial Position (Profit/Loss).
- Average Revenue per Athlete and Cost per Athlete.
- Collection Efficiency Rate and Scholarship Burden %.

Allows fair comparison across branches while flagging comparisons distorted by unequal season lengths or athlete counts.

---

## 20. Cash and Bank Account Center

The Cash and Bank Account Center tracks all physical cash boxes, bank accounts, and digital merchant balances.

### Supported Account Types
Branch Petty Cash Boxes, Main Club Operating Bank Accounts, Branch-Specific Bank Accounts, Payment Provider Merchant Balances, Dedicated Reserve Accounts, and Sponsorship Escrow Accounts.

### Ledger Operations
Displays Opening Balance, Current Balance, Available Liquid Balance, Pending Clearing Balance, Inflows, Outflows, Reconciled Balance, and Last Reconciliation Timestamp. Supports Cash Deposits, Cash Withdrawals, Inter-Account Transfers, Daily Cash Box Closings, and Reconciliation Sign-offs.

---

## 21. Reconciliation Center

The Reconciliation Center matches recorded platform charges and receipts against bank statements and payment records.

### Matching States & Taxonomy
- **Unmatched:** Bank transaction or cash entry lacking a linked platform record.
- **Suggested Match:** System highlights potential matching invoice based on amount, date, and payer name.
- **Partially Matched:** Received bank amount covers part of a multi-item invoice.
- **Matched:** Fully reconciled transaction verified by financial staff.
- **Disputed:** Transaction flagged for accounting investigation due to amount discrepancy.
- **Ignored with Reason:** Non-operational bank entries (e.g., bank fee charges) cleared with logged explanatory notes.

---

## 22. Contracts and Financial Documents

This module manages legal agreements, financial commitments, vendor contracts, and scholarship forms, integrating conceptually with Screen 8.

### Supported Document Types
Athlete Membership Agreements, Parent Payment Commitments, Scholarship Award Contracts, Sponsorship Agreements, Facility Rental Contracts, Vendor Supply Agreements, Staff Payment Contracts, and Refund Authorization Forms.

### Document Attributes & Expiration Tracking
Tracks Issue Date, Effective Start/End Dates, Total Contract Value, Signing Status (Pending, Signed), Attached Document Scans, and Renewal Warning Alerts triggered 30 days prior to contract expiration.

---

## 23. Financial Approval Workflows

Financial Approval Workflows enforce governance controls over high-impact financial actions.

### Action Threshold Matrix

| Action Type | Low Threshold (Auto / Admin Approval) | High Threshold (Financial Manager / Board Approval) |
| :--- | :--- | :--- |
| **Expense Submission** | $< \$500$ (Branch Admin) | $\ge \$500$ (Financial Manager / President) |
| **Discount Application** | Standard Policy ($< 15\%$) | Custom / High Discount ($\ge 15\%$) |
| **Scholarship Grant** | Standard Team Grant | Full Tuition Waiver / Special Fund |
| **Refund Request** | $< \$100$ (Branch Admin) | $\ge \$100$ (Financial Manager) |
| **Debt Write-Off** | N/A | Requires Dual Board Sign-Off |

### Approval Status Lifecycle
`Draft` $\longrightarrow$ `Submitted` $\longrightarrow$ `Under Review` $\longrightarrow$ `Approved` (or `Rejected` / `Returned for Correction`). All approval actions record mandatory timestamps, comments, and approver IDs.

---

## 24. Financial Audit Center

The Financial Audit Center provides an immutable, read-only audit log tracking every financial modification across the platform.

### Audited Financial Events
Creation or modification of charges, payment entries, payment reversals, applied discounts, approved scholarships, debt write-offs, refund approvals, expense edits, budget revisions, inter-account cash transfers, and document replacements.

### Audit Record Fields
Timestamp, Actor (User ID & Role), Action Type, Affected Record ID, Branch, Previous Field Value, New Field Value, Justification Note, and Linked Approval Reference. Audit records are strictly read-only and cannot be edited or deleted by any role.

---

## 25. Financial Reporting

The Financial Reporting module provides pre-configured operational financial reports, feeding insights into Screen 13 for executive analysis.

### Standard Financial Reports
Revenue Collection Summary, Outstanding Receivables Ledger, Debt Aging Analysis Report, Athlete Account Balance Statements, Parent Family Account Summaries, Discount & Scholarship Burden Report, Refund Summary Log, Expense Breakdown by Category, Budget vs. Actual Utilization Report, Branch Profitability Matrix, Team Financial Performance Report, Facility Financial Return Report, Cash Flow Summary, Bank & Cash Account Statements, Reconciliation Discrepancy Log, and Financial Audit Log Report.

All reports support multi-filtering by Date Range, Branch, Team, Sport, Account, Payment Method, Fee Plan, Expense Category, and Approval Status.

---

## 26. Search

Screen 14 features a global financial search bar providing rapid lookup across all financial entities.

### Search Vectors
Athlete Name/ID, Parent/Payer Name, Invoice Number, Receipt Number, External Transaction Reference, Charge ID, Expense Record ID, Vendor Name, Branch, Team, Facility, Bank Account Title, Contract Title, and Approval Request ID. Search results strictly adhere to user role permissions.

---

## 27. Filters

Screen 14 provides a persistent, multi-layered financial filter bar.

### Global Filter Options
Date Range (Presets & Custom Bounds), Branch, Sport, Team, Athlete Status, Payer Category, Payment Status (`Paid`, `Overdue`, `Partial`), Fee Plan, Payment Method (`Cash`, `Card`, `Wire`), Expense Category, Cost Center Code, Bank Account, Approval State, and Document Expiration Window. Active filter tags are displayed in a sticky top bar and can be cleared individually or reset completely.

---

## 28. Financial Alerts

Financial Alerts monitor operational fiscal health and warn managers of risks, errors, and threshold breaches.

### Alert Triggers & Classification
- **Critical (Red):** Severe debt overdue ($> 60$ days), cash box closing mismatch, unauthorized budget overrun ($> 100\%$), bank account balance below emergency threshold, low cash flow risk.
- **Warning (Amber):** Upcoming installment due within 3 days, failed payment attempt logged, unapproved refund pending $> 48$ hours, unallocated bank transfer received, contract expiring within 14 days, budget utilization $> 85\%$.
- **Information (Blue):** Payment successfully received, new invoice batch generated, standard receipt issued, expense claim submitted.

Every alert presents a clear explanation, affected amount, and a direct safe action link.

---

## 29. Permissions and Visibility

Screen 14 strictly enforces Role-Based Access Control (RBAC) to protect sensitive financial data.

### Role Authorization Matrix

| User Role | Executive Dashboard | Receivables & Billing | Record Payments | Expenses & Budgets | Refunds & Write-Offs | Bank Accounts & Cash | Personal / Family Balance Only |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Club Owner / President** | Full Access | Full Access | Full Access | Full Access | Full Approval | Full Access | N/A |
| **Club Administrator** | Full Access | Full Access | Full Access | Full Access | Approval Limits | Full Access | N/A |
| **Financial Manager / Accountant** | Full Access | Full Access | Full Access | Full Access | Full Approval | Full Access | N/A |
| **Branch Manager** | Branch Only | Branch Only | Branch Only | Branch Expenses | Submit / Limit | Branch Cash Only | N/A |
| **Facility Manager** | Facility Costs | **No Access** | **No Access** | Facility Expenses | **No Access** | **No Access** | N/A |
| **Head Coach** | **No Access** | **No Access** | **No Access** | **No Access** | **No Access** | **No Access** | **No Access** |
| **Medical Staff** | **No Access** | **No Access** | **No Access** | **No Access** | **No Access** | **No Access** | N/A |
| **Parent / Guardian** | **No Access** | **No Access** | View / Pay Own | **No Access** | Request Own | **No Access** | **Full Access (Own Family)** |
| **Athlete** | **No Access** | **No Access** | View Own | **No Access** | **No Access** | **No Access** | **View Own Balance** |
| **Auditor** | Read-Only | Read-Only | Read-Only | Read-Only | Read-Only | Read-Only Logs | **No Access** |

---

## 30. Privacy and Sensitive Financial Data

Screen 14 incorporates privacy masking to safeguard personal financial records, banking details, and payment credentials.

### Privacy Rules
- **Payment Card Data:** Full credit/debit card numbers and CVV codes are **never** stored or displayed. Interface displays only masked representations (e.g., `•••• •••• •••• 4242`).
- **Bank Account Masking:** External payer bank IBANs and account numbers are partially masked (e.g., `TR•• •••• •••• 9876`).
- **Staff Compensation Privacy:** Staff salaries and coach remuneration expense details are restricted strictly to Financial Managers and Club Owners. Branch Managers see aggregated labor expense totals only.
- **Non-Expansion on Export:** Exported PDFs and Excel files inherit all active role privacy masking. Masked fields remain masked in exported files.

---

## 31. Error and Empty States

Screen 14 provides clear, safety-first error and empty states for all operational exceptions.

### Exception Handling Matrix
- **No Financial Data / Transactions:** Displays a neutral graphic stating *"No financial records match your current filter settings."* Provides a `"Reset Filters"` button.
- **No Active Fee Plans:** Displays an onboarding screen prompting the administrator to create baseline membership fee plans.
- **Overpayment / Allocation Conflict:** Displays a warning modal stating *"Payment amount exceeds total outstanding invoice balance. Excess amount will be credited to Parent Account Balance."*
- **Refund Exceeds Paid Total:** Blocks the action and displays an error stating *"Invalid Refund Amount: Requested refund exceeds original payment total."*
- **Permission Denied Screen:** Renders a masked screen stating *"Financial Access Restricted: Your role does not have authorization to view financial account details."*
- **Stale Financial Data Warning:** Displays an amber top banner stating *"Financial records pending sync. Balance reflects updates as of [Timestamp]."*, with a manual `"Sync Financials"` trigger.

---

## 32. Responsive Behaviour

Screen 14 delivers an optimized financial workspace adapted for phone, tablet, desktop, and ultra-wide screens.

### Device-Specific Ergonomics
- **Mobile (Phone):** Focuses on parent payment views, athlete balance summaries, quick cash receipt recording, and urgent financial alerts. Uses bottom-sheet drawers for filters and payment entry.
- **Tablet:** Two-column layout pairing member account lists with detail ledgers. Optimized for touch interaction during onsite cash collections and mobile expense approvals.
- **Desktop / Workstation:** Multi-pane workspace featuring persistent multi-filters, full transaction tables, side-by-side document previews, budget planning grids, and reconciliation workspaces.
- **Ultra-Wide Display:** High-density executive command layout presenting multi-branch financial matrices, cash account summaries, real-time alert queues, and key KPI blocks without empty whitespace.

---

## 33. Accessibility

Screen 14 complies fully with **WCAG 2.1 Level AA** guidelines for accessible financial operations.

### Accessibility Features
- **Accessible Currency Narration:** Screen reader labels articulate currency amounts clearly (e.g., "One hundred fifty Dollars and zero Cents" instead of raw text "$150.00").
- **Non-Color Dependent Financial States:** Financial statuses combine color with clear icons and text labels (e.g., Red Square + "Overdue", Green Check + "Paid", Amber Triangle + "Partial").
- **Table Alternatives for Financial Charts:** Every financial chart includes a screen-reader-accessible HTML table toggle.
- **Keyboard Navigation & Focus Rings:** Complete keyboard accessibility (`Tab`, `Enter`, `Space`, `Esc`) with visible high-contrast focus rings around all financial inputs, action buttons, and table rows.
- **Numeric Contrast & Scaling:** Financial figures enforce a minimum 4.5:1 contrast ratio against backgrounds and support 200% text scaling without overlapping columns.

---

## 34. Data Trust and Financial Integrity

Screen 14 provides clear indicators of financial data authenticity and audit trust.

### Integrity Badges & Indicators
- **Reconciled vs. Unreconciled Status:** Clear badges indicating whether a ledger entry has been verified against bank statements.
- **Draft vs. Finalized Indicator:** Prominent banners preventing accidental reliance on unissued draft invoices or draft budgets.
- **Audit Verification Stamp:** Displaying last audit timestamp and verifying user ID on formal receipts and statements.
- **Unallocated Funds Warning:** Prominent alert banners warning managers when unallocated cash payments or unmatched wire transfers exist in the system.

---

## 35. Future Expansion

Screen 14 is architected with structural readiness slots to accommodate future financial technology integrations without requiring UI refactoring.

### Extensibility Readiness Slots
- **Online Payment Gateways:** Interface slots for direct digital payment link generation and web checkouts.
- **Bank API & Open Banking Integration:** Readiness for automated electronic bank statement fetching and instant reconciliation.
- **Electronic Invoicing & Tax Engines:** Schema compatibility for national e-invoice registry submission and localized automated tax calculation.
- **Automated Payroll & Coach Stipends:** Integration hooks for automated calculation of coaching hours and direct stipend payouts.
- **Multi-Currency & Exchange Rates:** Data readiness for supporting international athlete tuition and multi-currency bank accounts.

---

## 36. Frozen Product Decisions

To ensure 100% full compatibility with frozen platform screens (Screens 1–13), the following core product decisions are permanently locked:

1. **Source of Truth for Financial Operations:** Screen 14 is the sole system authority for managing charges, receiving payments, issuing refunds, recording expenses, and maintaining account ledgers.
2. **Read-Only Data Consumption from Screens 1–13:** Screen 14 consumes operational context (rosters, attendance, facility schedules, medical clearance) strictly in read-only mode and cannot mutate operational records in source modules.
3. **Automated Non-Payment Roster Holds:** Delinquent debt past configured grace periods automatically places an athlete's participation status on `Financial Hold` in Screen 3 and Screen 5, preventing match selection until cleared.
4. **Uncompromised Medical Privacy Isolation:** Financial managers and accountants have zero access to clinical doctor notes or medical diagnosis details in Screen 12 when reviewing injury-related refund requests.
5. **Strict Permission & Privacy Non-Expansion:** Exporting financial ledgers, generating PDF statements, or sharing saved report templates **never** bypasses underlying user role permissions or privacy masking rules.

---

**Screen 14 Product Specification v1.0**
