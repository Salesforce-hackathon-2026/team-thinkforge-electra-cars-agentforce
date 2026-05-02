# 🚗 Electra Cars - AI-Powered Test Drive Booking on Salesforce

> **Agentforce-powered test drive booking with geo-based dealer discovery, real-time slot availability, and personalized website nudges built on Salesforce Automotive Cloud, Scheduler, Personalization, Data Cloud and Experience Cloud.**

---

## 📌 Table of Contents

- [Problem Statement](#problem-statement)
- [Solution Overview](#solution-overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Solution Walkthrough](#solution-walkthrough)
  - [Layer 1 - Website, Data Cloud and Personalization](#layer-1--website-data-cloud-and-personalization)
  - [Layer 2 - Agentforce Conversational Booking](#layer-2--agentforce-conversational-booking)
- [Data Model](#data-model)
- [Agentforce Agent Actions](#agentforce-agent-actions)
- [Salesforce Scheduler Setup](#salesforce-scheduler-setup)
- [Key Apex Classes](#key-apex-classes)
- [Salesforce Features Used](#salesforce-features-used)
- [Demo](#demo)

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
| **Flow** | Appointment booking orchestration |

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
- 5 parent territories at city level for Mumbai, Pune, Kolkata, kanpur and Delhi
- 3 child territories, with geocoded lat/lon addresses
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

This class computes real-time test drive slot availability without any dependency on LxScheduler or FSL licenses, making it fully compatible with the Einstein Agent Service user which cannot hold a Salesforce Scheduler license.

How it works:
1. Fetches WorkType duration
2. Finds the primary active sales rep for the territory via ServiceTerritoryMember
3. Retrieves OperatingHoursId from ServiceTerritory
4. Loads all TimeSlot records and supports multiple shifts per day
5. Queries existing ServiceAppointment records to identify booked slots
6. Queries ResourceAbsence records to block rep unavailability
7. Loops through each day in the search window and generates available slots respecting all constraints
8. Returns a structured list of SlotOption objects with displayTime, slotDate and slotTime

Note: The Einstein Agent Service user cannot hold a Salesforce Scheduler license. This SOQL-based approach has zero license dependency and works with any user that has basic Read permissions on the relevant objects.

### AF_TerritoryRoutingInvocable

This class resolves customer location and finds nearest dealerships:
1. Accepts zip/pin code as input
2. Looks up lat/lon from ZipCentroid__mdt custom metadata
3. Runs SOQL DISTANCE() query on ServiceTerritory to find nearest dealerships within configured radius
4. Returns ordered list of dealerships by distance

### AF_GetWeatherInsights

This class fetches weather information for the selected test drive date and location, giving the customer a heads up on what conditions to expect on the day of their test drive. The weather data is surfaced conversationally by the agent before the customer confirms their slot.

### TwilioWhatsAppService

This class handles all WhatsApp communication via the Twilio WhatsApp API. It sends the outbound booking confirmation to the customer after slot confirmation, including the unique booking code, dealership address, calendar invite and Google Maps link. It also handles inbound customer messages for any follow-up notifications.


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
- A `dmlPerformed` flag tracks whether a database update has occurred, and switches the WhatsApp callout to an `@future` method to avoid the Salesforce callout-after-DML governor limit error
- Returns empty TwiML 200 OK response to Twilio after every inbound message

