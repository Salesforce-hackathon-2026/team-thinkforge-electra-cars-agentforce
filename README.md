# 🚗 Electra Cars - AI-Powered Test Drive Booking on Salesforce

> **Agentforce-powered test drive booking with geo-based dealer discovery, real-time slot availability, and personalized website nudges built on Salesforce Automotive Cloud, Scheduler, Personalization, Data Cloud and Experience Cloud.**

---

## 📌 Table of Contents

- [Problem Statement](#problem-statement)
- [Solution Overview](#solution-overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Solution Walkthrough](#solution-walkthrough)
  - [Layer 1 - Website, Data Cloud and Personalization](#layer-1---website-data-cloud-and-personalization)
  - [Layer 2 - Agentforce Conversational Booking](#layer-2---agentforce-conversational-booking)
- [Data Model](#data-model)
- [Agentforce Agents and Actions](#agentforce-agents-and-actions)
- [Salesforce Scheduler Setup](#salesforce-scheduler-setup)
- [Key Apex Classes](#key-apex-classes)
- [Flows](#flows)
- [External Integrations](#external-integrations)
- [Future Roadmap](#future-roadmap)

---

## 🔴 Problem Statement

Traditional test drive booking at automotive dealerships is a friction-heavy, manual process. Customers fill out static forms, wait for callbacks, and have no visibility into nearest dealerships or available slots. Dealership teams manually coordinate appointments, leading to delays, missed leads, and poor customer experience.

**Electra Cars needed a modern, AI-first experience** that meets customers on the website, engages them proactively, and takes them from first visit to a confirmed test drive booking in minutes, with no manual intervention.

---

## ✅ Solution Overview

The solution is majorly website-facing where the test drive booking experience lives. Using Experience Cloud, the website is managed leveraging content from Salesforce CMS, offering a seamless and engaging digital showroom where customers can explore Electra Cars, discover vehicles and initiate their test drive journey.

The moment a customer lands on the Electra Cars website, the experience begins working for them. After 30 seconds on the homepage, a personalized AI nudge appears, a friendly message card from the Electra Test Drive Advisor inviting them to book a test drive. The message, tone and call-to-action are fully controlled by Salesforce Personalization, so the right message always reaches the right visitor at the right time.

When the customer is ready, they simply click Book A Test Drive and land on the Agentforce agent page. The customer says Hi and the conversation begins. The agent auto captures the vehicle they are interested in from context, then asks for their name. The agent then auto-detects their location using IP address to instantly surface the nearest Electra dealerships. Once the dealership is confirmed, the agent shows real-time available time slots along with weather insights for the test drive date. The customer selects a convenient slot and the agent collects their phone number for WhatsApp confirmation and email (optional), all through a natural back-and-forth conversation, no forms, no waiting.

Once confirmed, the booking is locked in automatically. The dealership gets the appointment notification in their Slack channel, the customer's details are captured as a lead in Salesforce, and a confirmation with a unique booking code, dealership details, calendar invite and dealership Google Maps location is sent to the customer instantly on WhatsApp.

The entire experience from the first website visit to a confirmed test drive happens in minutes, with no manual intervention from the dealership team.

---

## 🏗️ Architecture

```
Customer on Experience Cloud Website
         |
         v
+-----------------------------------------+
|  Layer 1 - Data Cloud & Personalization |
|                                         |
|  Data Cloud                             |
|  Websites & Mobile Apps Connector       |
|  -> Behavioural Events Data Stream      |
|  -> Identity Data Stream                |
|  -> Mapped to Individual, Website       |
|     Engagement, Privacy Consent Log     |
|                                         |
|  Salesforce Personalization             |
|  -> Captures page behaviour via         |
|     sitemap.js                          |
|  -> 30s slide-in nudge (Chat Overlay)   |
|  -> Exit Intent Overlay                 |
|     "Wait - before you go!"             |
|  -> Content controlled via Decisions    |
+-----------------------------------------+
         |
         v  Customer clicks Book A Test Drive
+-----------------------------------------+
|  Layer 2 - Agentforce Booking           |
|                                         |
|  Customer lands on Agent page           |
|         |                               |
|  Customer says Hi                       |
|         |                               |
|  Agent auto captures vehicle interest   |
|  from context                           |
|         |                               |
|  Agent asks for customer name           |
|         |                               |
|  IP -> lat/lon -> DISTANCE() SOQL       |
|  -> Auto detects nearest dealerships    |
|         |                               |
|  Customer confirms dealership           |
|         |                               |
|  AF_GetDealerSlotsInvocable             |
|  -> WorkType + TimeSlot + SA query      |
|  -> Available slots returned            |
|         |                               |
|  Agent shows weather insights           |
|  for selected slot date                 |
|         |                               |
|  Customer confirms time slot            |
|         |                               |
|  Agent asks for phone number            |
|  Email collected (optional)             |
|         |                               |
|  ServiceAppointment created             |
|  Lead upserted                          |
|  TestDrive__c record created            |
|         |                               |
|  Slack notification to Dealership       |
|  WhatsApp confirmation to Customer      |
+-----------------------------------------+
```

---

## 🛠️ Technology Stack

| Salesforce Product | How It Is Used |
|---|---|
| **Experience Cloud** | Customer-facing website and digital showroom for Electra Cars |
| **Salesforce CMS** | Manages website content including pages, banners and vehicle content |
| **Data Cloud** | Website data ingestion via Websites and Mobile Apps connector, Data Streams, Data Model mapping (Individual, Website Engagement, Privacy Consent Log) and Identity Resolution |
| **Salesforce Personalization** | Personalization Points, Response Templates, Decisions powering the 30-second nudge and exit intent overlay |
| **Agentforce** | Conversational AI agent handling the full test drive booking flow |
| **Apex (@InvocableMethod)** | Custom Agent Actions for geo-based dealer lookup, real-time slot retrieval, weather insights and WhatsApp notifications via Twilio |
| **Salesforce Scheduler** | WorkType, ServiceTerritory, TimeSlot, ServiceAppointment and ResourceAbsence objects |
| **Automotive Cloud** | Vehicle__c standard object and TestDrive__c custom object |
| **Slack** | Real-time appointment notification to dealership channel |
| **Twilio - WhatsApp** | Booking confirmation sent via Twilio WhatsApp API using a custom Apex class, including unique booking code, dealership details, calendar invite and Google Maps location. Inbound customer notifications also handled via custom Apex |
| **Flow** | Appointment booking orchestration across 8 flows covering agent actions, record triggers and Slack notifications |

---

## 🔍 Solution Walkthrough

### Layer 1 - Website, Data Cloud and Personalization

The Electra Cars website is built on Salesforce Experience Cloud with content managed through Salesforce CMS, giving business users full control over vehicle listings, banners and pages without developer involvement.

---

#### Data Cloud - Website Data Ingestion and Unified Profile

Data Cloud is used for website data ingestion and customer profile unification. The Electra Cars Experience Cloud website is connected to Data Cloud via the Websites and Mobile Apps connector, which sets up two data streams. One stream captures behavioural events like page views, clicks and interactions, and another captures identity signals from website visitors.

These streams are mapped to the Data Cloud standard data model. Behavioural events map to Website Engagement and Privacy Consent Log, while identity signals map to the Individual profile object. This builds a unified, consent-aware customer profile from the moment someone visits the website, even before they identify themselves.

| Data Stream | Purpose |
|---|---|
| ElectraCarsWeb-Behavioral Events | Captures page views, clicks and interactions across the website |
| ElectraCarsWeb-identity | Captures identity signals including cookie ID and known user identity |

| Data Model Mapping | Type | Purpose |
|---|---|---|
| Individual | Profile | Unified customer profile from website identity signals |
| Website Engagement | Engagement | Behavioural events mapped to standard engagement model |
| Privacy Consent Log | Engagement | Consent captured on the website, GDPR compliant |

---

#### Salesforce Personalization - Proactive Engagement

Salesforce Personalization is used to proactively engage website visitors at two key moments in their journey. As customers browse the Electra Cars website, their behaviour across pages is continuously captured, what they are viewing, which vehicles they are exploring and how they are navigating, giving the system real-time context about their intent.

This powers two live nudges.

The first is a 30-second nudge, a bottom-left slide-in card that invites the customer to book a test drive with the Electra AI Agent before they have even thought about leaving.

The second is an exit intent overlay triggered when the customer is about to navigate away from the website. A full-screen card appears with the message "Wait - before you go!", highlighting that the AI can match them with the perfect Electra model and book a test drive at their nearest dealership in under 2 minutes, with a direct Chat with Electra CTA.

Both nudges are fully managed by the marketing team through Decisions. The message, tone and CTA can be updated anytime with zero code changes.

In future, this behavioural data can be tied to a unified customer profile post-purchase to deliver a deeply personalised experience across the entire ownership journey.

| Personalization Point | Response Template | Purpose |
|---|---|---|
| Electra Car Chat Overlay | Electra Car Chat Overlay | 30-second slide-in booking nudge |
| Electra Exit Intent Overlay | Electra Exit Intent Nudge | Exit intent full-screen retention overlay |

---

### Layer 2 - Agentforce Conversational Booking

When the customer clicks Book A Test Drive from the homepage, the AI nudge or the exit intent overlay, the Agentforce conversation begins.

| Step | What Happens |
|---|---|
| 1 | Customer clicks Book A Test Drive from the homepage or vehicle explore page |
| 2 | Customer lands on the Agentforce agent page |
| 3 | Customer says Hi and the conversation begins |
| 4 | Agent auto captures the vehicle the customer is interested in from context |
| 5 | Agent asks for the customer name |
| 6 | Agent auto-detects customer location via IP address, resolves to lat/lon and finds the nearest Electra dealerships |
| 7 | Customer confirms their preferred dealership |
| 8 | Agent fetches real-time available time slots for the confirmed dealership |
| 9 | Agent shows weather insights for the dates of available slots |
| 10 | Customer confirms their preferred time slot |
| 11 | Agent asks for the customer phone number and optionally collects email address |
| 12 | ServiceAppointment created in Salesforce Scheduler |
| 13 | Lead upserted with customer details and vehicle interest |
| 14 | TestDrive__c record created linking all entities with a unique confirmation code |
| 15 | WhatsApp confirmation sent to customer with booking code, dealership details, calendar invite and Google Maps location |
| 16 | Slack notification sent to the dealership channel |

---

## 📊 Data Model

### Standard Objects Used

| Object | Purpose |
|---|---|
| `Lead` | Customer details including name, phone, email, zip, vehicle interest and preferred channel |
| `Account` | Dealerships with Record Type as Dealer, DealerCode__c and ServiceRadius_km__c |
| `Asset` | Automotive Cloud standard object for vehicle models and trims |
| `Contact` | Post-conversion from Lead after booking confirmation |
| `ServiceTerritory` | One per dealership with geocoded lat/lon and linked operating hours |
| `ServiceResource` | Sales reps as Technician type and demo vehicles as Asset type |
| `ServiceAppointment` | Created on booking confirmation and links territory, resource and time |
| `WorkType` | Defines the Test Drive appointment template with duration, buffer and hours |
| `TimeSlot` | Defines working hours intervals within Operating Hours |
| `ResourceAbsence` | Blocks slots when a rep is on leave or unavailable |

### Custom Objects Built

| Object | Purpose |
|---|---|
| `TestDrive__c` | Central booking record linking Lead, Vehicle, Dealership, ServiceAppointment, ConfirmationCode and AgentSessionId |

---

## ⚡ Agentforce Agents and Actions

### Agent 1 - ElectraCars Test Drive Booking Agent (Customer Facing)

This is the primary customer-facing agent embedded on the Electra Cars Experience Cloud website. It handles the full test drive booking journey from start to confirmation.

| Agent Action | Purpose |
|---|---|
| Get Vehicle Name and Store | Fetches available Electra vehicle details and captures the vehicle the customer is interested in |
| Find Nearest Dealership Territory (5 to 50 km) | Auto-detects customer location via IP, resolves to lat/lon and finds the nearest Electra dealerships using SOQL DISTANCE() on ServiceTerritory |
| Get Available Test Drive Slots for Territory | Queries WorkType, TimeSlot, ServiceAppointment and ResourceAbsence to return real-time available slots for the confirmed dealership |
| Get Weather for Dealer Territory | Fetches weather insights for the test drive date and dealership location so the customer knows what to expect on the day |
| Test Drive Appointment Details | Creates the Lead record using customer name and address details provided during the conversation |
| Service Appointment Creation | Creates the ServiceAppointment in Salesforce Scheduler once the customer confirms their slot |
| Send WhatsApp Booking Confirmation | Sends the booking confirmation to the customer via Twilio WhatsApp API including booking code, dealership details, calendar invite and Google Maps location |

---

### Agent 2 - Dealership Service Agent (Dealer Facing)

This is a separate internal agent built for dealership staff. It is connected to Slack and can be invoked directly from the dealership Slack channel, allowing staff to manage test drive bookings without logging into Salesforce.

| Agent Action | Purpose |
|---|---|
| Update_ServiceAppointment_Status | Allows dealership staff to update the status of a Service Appointment, for example cancelling or completing a test drive booking, directly from Slack |

---

## 📅 Salesforce Scheduler Setup

### Operating Hours
- Record: Mon-Sat 9AM-6PM IST
- Timezone: Asia/Kolkata
- Shift 1: Monday to Saturday 09:00 to 13:00
- Shift 2: Monday to Saturday 15:00 to 18:00
- Type: Normal

### Service Territories
- 5 parent territories at city level for Mumbai, Pune, Kolkata, Kanpur and Delhi
- 3 child territories with geocoded lat/lon addresses
- Geocoding enabled via Data Integration Rules for Geocodes on Service Territory Address

### Work Type
- Name: Test Drive - 60 min
- Duration: 60 minutes
- Block Before: 15 minutes
- Appointment Category: Scheduled
- Operating Hours: Mon-Sat 9AM-6PM IST

### Service Resources
- Skill: Test Drive Assistant at level 80
- Resource Type: Technician for sales reps and Asset for demo vehicles
- One resource per dealership assigned as Primary territory member

---

## 🔧 Key Apex Classes

### AF_GetDealerSlotsInvocable

Computes real-time test drive slot availability without any dependency on LxScheduler or FSL licenses, making it fully compatible with the Einstein Agent Service user which cannot hold a Salesforce Scheduler license.

How it works:
1. Fetches WorkType duration
2. Finds the primary active sales rep for the territory via ServiceTerritoryMember
3. Retrieves OperatingHoursId from ServiceTerritory
4. Loads all TimeSlot records and supports multiple shifts per day (e.g. 9AM-1PM and 3PM-6PM)
5. Queries existing ServiceAppointment records to identify booked slots
6. Queries ResourceAbsence records to block rep unavailability
7. Loops through each day in the search window and generates available slots respecting all constraints
8. Returns a structured list of SlotOption objects with displayTime, slotDate and slotTime

Note: This SOQL-based approach has zero license dependency and works with any user that has basic Read permissions on the relevant objects.

---

### AF_TerritoryRoutingInvocable

Resolves customer location via IP address to lat/lon coordinates and finds the nearest Electra dealerships using SOQL DISTANCE() on ServiceTerritory. Returns an ordered list of dealerships within the configured radius (5 to 50 km).

---

### AF_GetWeatherInsights

Fetches weather information for the selected test drive date and dealership location. The weather data is surfaced conversationally by the agent after showing available slots, giving the customer useful context before they confirm their booking.

---

### TwilioWhatsAppService

Handles all outbound WhatsApp communication via the Twilio WhatsApp API. Sends the booking confirmation to the customer after slot confirmation, including the unique booking code, dealership address, calendar invite and Google Maps link.

---

### TwilioInboundWebhook

A REST API endpoint (`@RestResource urlMapping='/twilio/inbound'`) that handles all inbound WhatsApp messages from customers via Twilio. It acts as a self-service post-booking support handler.

Supported customer intents:

| Customer Message | What Happens |
|---|---|
| CANCEL followed by Booking ID | Verifies phone number against ServiceAppointment, cancels the appointment and sends a WhatsApp confirmation |
| RESCHEDULE followed by Booking ID | Verifies phone number, shows current booking details and directs customer to the website to pick a new slot |
| Yes / Yeah / Sure / OK | Sends a rebook link directing the customer back to the Electra Cars website |
| No / Nope / Not now | Sends a friendly closing message |
| Any other message | Sends a help menu showing CANCEL and RESCHEDULE instructions |

Key design decisions:
- Phone verification runs before any DML to ensure a customer can only cancel or reschedule their own booking
- A `dmlPerformed` flag tracks whether a database update has occurred and switches the WhatsApp callout to an `@future` method to avoid the Salesforce callout-after-DML governor limit error
- Returns empty TwiML 200 OK response to Twilio after every inbound message

---

## 🔄 Flows

The solution uses 8 Flows across different trigger types and purposes.

| Flow | Type | Trigger | Purpose |
|---|---|---|---|
| Route to ElectraCars Agent from Exp Cloud | Routing Flow | Messaging Session | Routes incoming website chat sessions to the ElectraCars Agentforce agent. Gets vehicle name from context and updates the Messaging Session before routing |
| Get Vehicle Names and Store | Autolaunched Flow | Agent Action | Queries all Asset records, retrieves vehicle names and stores them as output for the agent to present to the customer |
| Test Drive Appointment Details | Autolaunched Flow | Agent Action | Creates the Lead record using customer name and address details captured during the conversation |
| Service Appointment Creation | Autolaunched Flow | Agent Action | Validates phone number format, creates the ServiceAppointment record, assigns the ServiceResource, updates the Lead record with appointment details and fetches the ServiceTerritory address |
| Create Test Drive Record | Autolaunched Flow | Record After Save on ServiceAppointment | Triggered automatically when a ServiceAppointment is created or updated. Creates a new TestDrive__c record on creation and keeps it in sync on subsequent updates |
| Booking Confirmation to Dealership | Autolaunched Flow | Record After Save on ServiceAppointment | Triggered when a ServiceAppointment is created. Looks up the linked TestDrive__c record and sends a Slack notification to the correct dealership channel based on territory |
| Booking Cancellation to Dealership | Autolaunched Flow | Record After Save on ServiceAppointment | Triggered when a ServiceAppointment is cancelled. Checks whether cancellation was initiated by the customer via WhatsApp or the dealer, sends a Slack notification to the dealership and sends a WhatsApp cancellation confirmation to the customer via TwilioWhatsAppService |
| Update ServiceAppointment Status | Autolaunched Flow | Agent Action | Used by the Dealership Service Agent via Slack. Finds the ServiceAppointment by ID, validates the status value and updates it to Cancelled, Cannot Complete or Completed. Returns a confirmation or error message back to the dealer |

---

## 🔗 External Integrations

### Twilio Inbound Webhook

This endpoint is registered in Twilio as the inbound webhook URL. When a customer sends a WhatsApp message to cancel or reschedule their booking, Twilio posts the message payload to this URL. The TwilioInboundWebhook Apex class processes the message, verifies the customer's phone number, updates the ServiceAppointment status to Cancelled and syncs the change to the linked TestDrive__c record automatically.

```
https://orgfarm-543580c7c8.my.salesforce-sites.com/twiliowebhook/services/apexrest/twilio/inbound
```

### Open-Meteo Weather API

This free weather forecast API is called by the AF_GetWeatherInsights Apex class. It returns weather forecast data for the selected test drive date and dealership location, which the agent surfaces conversationally to help the customer make an informed decision before confirming their slot.

```
https://api.open-meteo.com/v1/forecast
```

---

## 🚀 Future Roadmap

- Leveraging Agentforce Voice for booking test drives with a natural phonic conversation
- WhatsApp channel alignment directly from Salesforce without depending on third-party applications such as Twilio
- Creating an Electra Cars WhatsApp Business channel tied to Agentforce so that existing customers can use WhatsApp to request any kind of service
- Implementing a login feature for customers so they have their own profile including saved preferences and cart
- Implementing a "build your own car" experience with a cart, and triggering abandoned cart notifications through Salesforce Personalization
- When a lead is converted to a contact post-purchase, tying the unified Data Cloud profile to the web behaviours captured during the lead stage for a richer ownership experience
- Improvements to the Dealership Service Agent to handle full booking management capabilities including staff onboarding and offboarding
- Leveraging the full-fledged Automotive Cloud core data model for a production-grade implementation
