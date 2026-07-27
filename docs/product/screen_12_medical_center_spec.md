# 🩺 SWANSPORT — SCREEN 12 PRODUCT SPECIFICATION
## Medical Center & Athlete Health Management

---

## 1. Executive Summary

Screen 12 (Medical Center & Athlete Health Management) is the enterprise health governance and athlete welfare hub within the SwanSport platform. Operating as a unified, multi-branch medical management engine, Screen 12 bridges clinical health care, athlete safety, regulatory compliance, and performance readiness.

The core objective of Screen 12 is to establish an uncompromised standard of athlete care while automating medical eligibility enforcement across all sports branches, age groups, and competition tiers. By centralizing health profiles, certificate lifecycles, injury rehabilitation pipelines, medication/allergy tracking, and medical alerts, SwanSport empowers medical personnel (doctors, physiotherapists) to deliver targeted care while providing club leadership, coaches, and parents with clear, privacy-compliant operational visibility.

---

## 2. Product Vision

Screen 12 transforms sports health management from reactive paper records into a proactive, intelligent health center. It acts as the ultimate authority for athlete participation safety, ensuring no athlete steps onto a training pitch or match venue without verified medical clearance.

### Conceptual Inter-Module Integration
Screen 12 operates in total harmony with the existing frozen platform ecosystem:
- **Screen 3 (Athlete Management):** Serves as the identity baseline. Screen 12 enriches athlete rosters with live health badges, emergency cards, and participation readiness tags without modifying core athlete identity records.
- **Screen 5 (Training Planning):** Directly controls athlete training participation. Medical eligibility statuses and load restrictions set in Screen 12 automatically filter training rosters and restrict drill intensities in Screen 5.
- **Screen 6 (Calendar):** Synchronizes medical milestones. Certificate expiration dates, periodic medical examinations, treatment sessions, and target return-to-play dates seamlessly populate team and athlete calendar views.
- **Screen 9 (Administration):** Provides executive compliance reporting, audit trail logging for sensitive record access, and enterprise health policy settings across all club branches.
- **Screen 11 (Facility Management):** Integrates treatment room booking and rehabilitation equipment allocation. Physiotherapy sessions and rehab routines scheduled in Screen 12 automatically reserve medical room slots in Screen 11.

---

## 3. Athlete Health Profile

Every athlete registered in SwanSport possesses a centralized, multi-dimensional Athlete Health Profile. The profile serves as a single source of health truth accessible according to role-based privacy controls.

### Baseline Physical Attributes
- **Blood Type:** ABO and Rh factor classification (e.g., A+, O-, AB+).
- **Height & Weight:** Current height (cm) and weight (kg) with historical growth/weight tracking curves.
- **Dominant Hand & Foot:** Primary biomechanical dominance (Left, Right, Ambidextrous) for medical and tactical reference.

### Emergency Contacts
- **Primary Emergency Contact:** Name, relationship, primary phone, secondary phone, physical address.
- **Secondary Emergency Contact:** Backup contact details for minor/adult athletes.
- **Personal/Family Physician:** Attending physician name, clinic/hospital affiliation, contact phone number.

### Clinical & Surgical History
- **Known Allergies:** Categorized allergy ledger with critical severity flags.
- **Chronic Conditions:** Ongoing medical conditions (e.g., Asthma, Type 1 Diabetes, Epilepsy) with emergency care protocols attached.
- **Current Medications:** Active therapeutic prescriptions and dosage schedules.
- **Previous Surgeries & Hospitalizations:** Chronological surgical history detailing procedure type, date, surgical center, and clearance notes.
- **Medical Restrictions:** Specific physical limitations (e.g., "No contact drills," "Max 45 min play duration," "Avoid synthetic turf").
- **Doctor Notes:** Confidential clinical observation logs recorded exclusively by authorized medical personnel.

---

## 4. Medical Eligibility

Medical Eligibility is the system-wide gatekeeper governing athlete participation in training sessions, friendly games, and official matches.

### Eligibility Status Taxonomy
1. **Eligible (Green):** Athlete possesses full medical clearance, valid required certificates, and zero active participation restrictions. Authorized for all training drills and official competition rosters.
2. **Temporarily Restricted (Yellow):** Athlete is managing a minor ailment, strain, or partial clearance. Authorized for modified, low-intensity, or non-contact training as specified by medical staff; automatically blocked from official match selection.
3. **Rehabilitation (Orange):** Athlete is under active rehabilitation protocol following injury or surgery. Strictly excluded from normal team training and match play; participation limited to structured rehab sessions.
4. **Suspended for Medical Reasons (Red):** Mandatory suspension enforced due to severe medical condition, acute concussion protocol, unverified cardiac evaluation, or physician order. Absolute prohibition from all physical club activities.
5. **Medical Clearance Required (Purple):** Triggered automatically when mandatory certificates expire, periodic health forms are missing, or post-injury recovery lacks final physician sign-off. Suspends participation until fresh documentation is verified.

### Product Behaviour on Training & Matches
- **Training Impact (Screen 5):** When a coach constructs a session, restricted or rehabilitation athletes are highlighted with visual warning tags. Coaches cannot assign restricted athletes to full-contact drills.
- **Match Roster Impact (Screen 3 & Screen 6):** Any status other than `Eligible` automatically locks the athlete's name on match squad selection screens. Attempting to select an ineligible athlete triggers a hard system block requiring Medical Director override.

---

## 5. Medical Certificates

Screen 12 governs the document lifecycle for all mandatory health, federation, and legal clearance certificates.

### Supported Certificate Types
- **Sports Eligibility Certificate:** Annual comprehensive physical exam certificate mandated by sports authorities.
- **Medical Examination Record:** Periodic ECG, blood work, or specialized physiological assessment reports.
- **Federation Medical Forms:** Official league or sports federation health declaration documents.
- **Insurance Documents:** Active health and sports injury insurance policy details and emergency claim numbers.
- **Consent Forms:** Signed parent/guardian medical treatment authorization and emergency care release forms.

### Document Metadata & Lifecycle Rules
Each certificate records:
- **Issue Date & Expiration Date:** Exact validity timeframe.
- **Issuing Authority:** Name of clinic, hospital, or certified physician issuing the document.
- **Validity State:** `Valid`, `Expiring Soon` (within 30 days), `Expired`, `Rejected/Invalid`.
- **Automated Reminders:** Triggered at 30-day, 15-day, 7-day, and 1-day thresholds to parents, athletes, and compliance officers.

### Enforcement Rule
When a mandatory certificate transitions to `Expired`, the system immediately demotes the athlete's status to `Medical Clearance Required`, revoking match eligibility without requiring manual administrative intervention.

---

## 6. Injury Management

The Injury Management engine provides a complete end-to-end incident logging and tracking workflow for acute and chronic sports injuries.

### Injury Incident Record Attributes
- **Injury Type:** Classification (e.g., Muscle Strain, Ligament Tear, Fracture, Concussion, Contusion, Tendinopathy).
- **Body Region:** Anatomical location selected via interactive 3D body map or region selector (e.g., Left Knee - ACL, Right Ankle - Lateral Ligament, Lumbar Spine).
- **Severity Level:** `Minor` (1-7 days recovery), `Moderate` (8-28 days), `Severe` (1-3 months), `Critical` (3+ months / season-ending).
- **Injury Date & Context:** Date, time, and context of occurrence (e.g., Match - 65th Min, Training Drill, Off-Field Incident).
- **Estimated Recovery Timeframe:** Projected days/weeks to recovery.
- **Rehabilitation Plan Linkage:** Direct reference to the active treatment protocol in the Rehabilitation Center.
- **Attending Physician & Lead Physiotherapist:** Assigned healthcare professionals responsible for care.
- **Target Return-to-Play Date:** Dynamic estimated date adjusted based on milestone achievements.

### Visual Injury Timeline
A chronological visual stream detailing an athlete's entire injury history across their career in the club, including diagnosis dates, treatment milestones, surgery records, and actual vs. projected return-to-play durations.

---

## 7. Rehabilitation Center

The Rehabilitation Center tracks an athlete's step-by-step physical recovery journey from acute injury to full competition readiness.

### Multi-Stage Recovery Framework
1. **Phase 1: Acute Recovery & Pain Management:** Focus on swelling reduction, immobilization, and basic tissue healing.
2. **Phase 2: Functional Mobility & Strength Restoration:** Re-establishing full range of motion, muscle activation, and light load bearing.
3. **Phase 3: Sport-Specific Conditioning:** Progressing to running protocols, agility drills, and non-contact sport movements.
4. **Phase 4: Full Return-to-Play Integration:** High-intensity contact drills, team session integration, and final readiness evaluation.

### Operational Features
- **Treatment Sessions:** Scheduling and logging daily/weekly therapy sessions (manual therapy, electrotherapy, hydrotherapy).
- **Exercise Plans:** Prescribing customized rehab drill routines with sets, reps, load, and video guidance.
- **Recovery Milestones:** Objective gatekeeping criteria (e.g., "90% limb symmetry index," "Zero pain in vertical jump test") required to advance between phases.
- **Readiness Assessment Score:** Quantitative 0-100% score evaluating physical and psychological readiness for match play.
- **Progress Notes:** Daily session notes recorded by physiotherapists detailing pain scores (VAS 1-10), swelling, and compliance.

---

## 8. Medication Management

The Medication Management module guarantees therapeutic safety and anti-doping compliance.

### Prescribed Medication Tracking
- **Medication Name & Class:** Therapeutic drug name and classification.
- **Dosage & Administration Route:** Specific dosage, frequency (e.g., twice daily after meals), and route (oral, inhaler, topical).
- **Treatment Cycle Duration:** Start date, scheduled end date, or chronic ongoing indicator.
- **Prescribing Physician:** Doctor name and medical registration license number.
- **Substance Compliance Check:** Visual warning indicator cross-referencing medication names against national and international prohibited substance lists (Anti-Doping / WADA compliance flagging concept).
- **Automated Dosage Reminders:** Mobile and push notifications dispatched to athletes and guardians for daily compliance.

---

## 9. Allergy Management

The Allergy Management module ensures immediate, high-visibility awareness of athlete allergies across all club operations.

### Allergy Categorization
- **Food Allergies:** Peanut, tree nut, gluten, dairy, shellfish, etc.
- **Medication Allergies:** Penicillin, NSAIDs, aspirin, local anesthetics, etc.
- **Environmental & Contact Allergies:** Latex, bee stings, pollen, synthetic grass, etc.

### Critical Alert Visibility
Allergies categorized as `Anaphylactic / Critical` trigger high-contrast warning badges across:
- The Athlete Health Profile header.
- Emergency Medical Quick-Cards accessible by team managers during away matches.
- Catering and travel manifest screens within administration modules.

---

## 10. Medical Alert Center

The Medical Alert Center acts as the central nerve center for urgent medical notifications, health compliance breaches, and clinical action items.

### Alert Classification & Trigger Matrix

| Alert Category | Trigger Condition | Severity Level | Target Audience |
| :--- | :--- | :--- | :--- |
| **Expired Certificate** | Medical certificate expiration reached | **Critical** (Red) | Club Admin, Medical Staff, Parent |
| **Active Participation Block** | Athlete marked Suspended/Rehab placed on match roster | **Critical** (Red) | Head Coach, Medical Director |
| **Rehabilitation Overdue** | Recovery milestone missed by > 7 days | **Warning** (Amber) | Lead Physiotherapist, Doctor |
| **Missing Consent Document** | Required treatment/travel consent form absent | **Warning** (Amber) | Club Admin, Parent |
| **Upcoming Medical Exam** | Annual exam due within 14 days | **Information** (Blue) | Athlete, Parent, Medical Staff |
| **Medication Schedule Alert** | Prescription renewal required | **Information** (Blue) | Medical Staff, Athlete |

### Management & Resolution
Alerts remain active in the top-level Medical Center navigation bar until resolved by authorized personnel (e.g., uploading a renewed certificate or signing off on a cleared milestone).

---

## 11. Health Dashboard

The Health Dashboard presents an executive overview of club-wide health performance, medical safety compliance, and team availability.

### Executive KPI Metrics
- **Healthy & Available Athletes:** Total count and roster percentage of fully eligible athletes across all branches.
- **Injured Athletes Breakdown:** Total active injury headcount categorized by severity (Minor, Moderate, Severe).
- **Active Rehabilitation Pipelines:** Total athletes currently progressing through Rehabilitation Phases 1 to 4.
- **Expiring / Expired Certificates Queue:** Actionable tally of documents needing immediate renewal.
- **Critical Medical Alerts:** Count of unresolved urgent safety warnings across the club.
- **Medical Compliance Score:** Aggregate percentage rating (0-100%) reflecting club-wide certificate validity, completed annual exams, and signed consent forms.

### Dashboard Visualizations
- Interactive branch/team health comparison charts.
- Injury distribution heatmaps by body region.
- Certificate compliance progress rings.

---

## 12. Search

Screen 12 features a high-performance, multi-entity search engine tailored for rapid clinical and administrative lookups.

### Supported Search Vectors
- **Search by Athlete:** Look up profiles by full name, athlete ID, jersey number, or team roster.
- **Search by Injury:** Filter records by injury type (e.g., "ACL Tear"), anatomical region ("Ankle"), or severity.
- **Search by Certificate:** Query documents by certificate title, validity status, or issuing hospital.
- **Search by Medical Professional:** Find all records managed by a specific Doctor or Physiotherapist.
- **Search by Medication / Allergy:** Identify all athletes currently taking a specific medication or possessing a specific allergy (e.g., "Peanuts").

---

## 13. Filters

To support complex multi-branch sports organizations, Screen 12 provides flexible, multi-layered data filtering.

### Multi-Dimensional Filter Categories
- **Branch / Sport:** Filter by physical branch (e.g., Main Complex, North Campus) or sport discipline (Football, Basketball, Volleyball, Swimming).
- **Team / Squad:** Filter by specific squad (e.g., U14 Elite, Senior Men's A Team).
- **Injury Status:** `No Active Injury`, `Acute Phase`, `Rehabilitation`, `Fully Recovered`.
- **Eligibility Status:** `Eligible`, `Temporarily Restricted`, `Rehabilitation`, `Suspended`, `Clearance Required`.
- **Rehabilitation Stage:** `Phase 1`, `Phase 2`, `Phase 3`, `Phase 4`.
- **Certificate Status:** `All Valid`, `Expiring in 30 Days`, `Expired`, `Missing Document`.
- **Age Group & Gender:** Filter by age categories (U8 through Senior) and gender divisions.

Filter combinations can be saved as custom presets (e.g., "U18 Expired Certificates View").

---

## 14. Permissions & Privacy

Given the highly sensitive nature of medical data, Screen 12 strictly enforces role-based access boundaries and confidentiality principles.

### Role-Based Authorization Matrix

| Persona | Health Profile Baseline | Clinical Doctor Notes | Diagnosis & Injury Details | Rehab Plan & Progress | Certificate Upload & Management | Medical Eligibility Status | Emergency Contacts |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Club Administrator** | Read Only | **No Access** | High-Level Summary | High-Level Summary | Full Access | Read Only | Read Only |
| **Medical Staff (Doctor)** | Full Access | **Full Access** | Full Access | Full Access | Full Access | Full Access (Clearance) | Full Access |
| **Physiotherapist** | Full Access | Read Only | Full Access | **Full Access** | Read Only | Update Recommendation | Full Access |
| **Head Coach** | Read Only | **No Access** | Participation Impact | Return Date Only | View Status | **Read Only (Enforced)** | Read Only |
| **Parent / Guardian** | Full Access (Child) | **No Access** | View Child Record | View Child Record | **Upload & View** | Read Only | Edit Own Contact |
| **Athlete** | View Own | **No Access** | View Own | View Own Plan | View Own | View Own | View Own |

### Privacy & Confidentiality Principles
- **Need-to-Know Separation:** Coaches receive actionable participation status and physical restrictions without exposing raw diagnostic clinical notes or private medical histories.
- **Emergency Break-Glass Protocol:** In critical medical emergencies, authorized team managers can trigger a audited "Emergency Medical Card" view displaying blood type, critical allergies, and emergency contact numbers. Every break-glass event generates an immutable log entry in Screen 9.

---

## 15. Error States

Screen 12 incorporates intuitive, clear user interface designs for all operational edge cases.

### Specific Error State Behaviours
- **No Medical Profile Exists:** Displays a prominent initialization prompt with a step-by-step creation wizard. Athlete status is automatically defaulted to `Medical Clearance Required` until baseline health data is recorded.
- **Expired Certificate State:** Replaces document preview with a high-contrast warning card detailing expiration date and issuing body. Displays a prominent "Upload Renewed Certificate" action button while locking match eligibility.
- **Restricted Athlete Override Attempt:** If a coach attempts to drag an ineligible or restricted athlete into a match lineup, the system blocks the action, displays an error modal stating the exact medical restriction, and provides a "Contact Medical Staff" link.
- **No Rehabilitation Plan Assigned:** When an injury is logged without an associated rehab plan, an amber banner appears on the athlete's medical file notifying the lead physiotherapist that a rehabilitation protocol is pending creation.
- **Permission Denied Screen:** When a user attempts to access restricted medical areas (e.g., a coach attempting to open clinical doctor notes), a polite, security-masked screen appears stating: *"Medical Privacy Protection: You do not have authorization to view clinical notes. Contact the Head Medical Officer for access inquiries."*
- **No Search Results State:** Displays a friendly empty state illustration with suggestions to broaden search queries or clear active multi-filters.

---

## 16. Responsive Behaviour

Screen 12 delivers an optimized user experience tailored to phone, tablet, and desktop form factors.

### Device-Specific Layout Adaptation
- **Mobile (Phone):**
  - Layout: Single-column vertical scroll stack.
  - Interaction: Bottom-sheet drawers for quick filter selection and emergency card views. Sticky bottom bar for immediate "Emergency Contact Call" action.
  - Navigation: Tabbed navigation toggling between Health Profile, Alerts, and Active Injuries.
- **Tablet:**
  - Layout: Split-screen two-column interface.
  - Left Panel: Master list of athletes with quick eligibility badges and search/filter header.
  - Right Panel: Detailed view panel displaying complete health profiles, interactive rehab timelines, and document previews. Touch and stylus optimized for drawing anatomical injury markers and signing clearance forms.
- **Desktop / Workstation:**
  - Layout: Multi-pane executive command dashboard.
  - Full grid data tables with batch operations (e.g., multi-select certificate reminders).
  - Side-by-side split screen showing live document preview alongside verification entry forms.
  - Persistent sticky top-bar displaying real-time club-wide Health Compliance KPI counters.

---

## 17. Accessibility

Screen 12 strictly adheres to **WCAG 2.1 Level AA** web and mobile accessibility standards.

### Accessibility Implementations
- **High Color Contrast:** All medical text, icons, and status badges maintain a minimum contrast ratio of 4.5:1 for standard body text and 7:1 for critical safety alerts against background colors.
- **Color-Independent Status Indicators:** Every medical eligibility state and alert level combines color with distinct iconography, shape outlines, and text labels (e.g., Red Octagon + "Suspended", Green Circle + "Eligible") so color-blind users (deuteranopia, protanopia) experience zero ambiguity.
- **Full Keyboard Navigation:** Complete interface navigable via keyboard (`Tab`, `Shift+Tab`, `Arrow keys`, `Enter`, `Esc`), with visible focus indicator rings surrounding active buttons, table rows, and modal dialogs.
- **Screen Reader Optimization:** Accessible ARIA labels and live region announcements (`aria-live="assertive"`) for dynamic medical alert notifications and search result updates.
- **Flexible Typography:** Layouts dynamically expand to accommodate text scaling up to 200% without clipping text or creating horizontal scroll overflows.

---

## 18. Future Expansion

Screen 12 is architected conceptually to support seamless integration with next-generation sports medicine and performance technology.

### Designed Extensibility Slots
- **Wearable Devices & IoT Telemetry:** UI slot readiness for live data sync from smartwatches, chest straps, and sleep trackers (e.g., HRV, resting heart rate, recovery scores).
- **Biometric & HR Sensors:** Interface hooks for continuous cardiovascular monitoring during high-intensity rehab sessions.
- **GPS & Load Tracking:** Capability to ingest tracking metrics (distance covered, sprint count, player load) from GPS vests to evaluate return-to-play readiness.
- **National & Federation Medical Systems:** Integration readiness for automated sync with official national sports ministry and league medical registries.
- **AI Injury Prediction Engine:** Extensible UI indicators for machine-learning-driven strain risk warnings based on acute-to-chronic workload ratios.
- **AI Recovery Recommendations:** Architectural readiness to display personalized, AI-suggested rehabilitation progression protocols based on historical recovery curves of similar injuries.

---

## 19. Frozen Product Decisions

To maintain 100% full compatibility with existing frozen platform screens (Screens 1–11), the following core product decisions are locked:

1. **Automated Roster Locking:** Any medical eligibility status other than `Eligible` strictly blocks athlete selection in Screen 3 (Athlete Management) and Screen 5 (Training Planning) without exception. No coach role can bypass a hard medical block.
2. **Strict Privacy Boundary:** Clinical doctor notes and diagnostic details remain strictly invisible to Coaches, Club Managers, and Administrators. Screen 12 exposes only non-clinical participation status, return-to-play dates, and physical restrictions to non-medical roles.
3. **Sole Authority for Health Status:** Screen 12 is the single source of truth for athlete participation status. Screens 5, 6, 9, and 11 consume eligibility data in read-only mode and cannot mutate health statuses directly.
4. **Mandatory Consent & Certificate Gate:** Missing or expired parent consent forms and sports certificates automatically transition an athlete to `Medical Clearance Required`, revoking competition eligibility across the entire platform.
5. **Cross-Module Facility Sync:** Scheduling rehabilitation therapy sessions or medical exams automatically blocks required medical treatment rooms and equipment in Screen 11 (Facility Management), preventing double-booking.

---

**Screen 12 Product Specification v1.0**
