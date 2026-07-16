# LUXI – Aesthetic Clinic Management System

## Project Overview

**LUXI** is a web-based Aesthetic Clinic Management System developed for **Luxuriskin Aesthetic Clinic**. The system centralizes the clinic's daily operations by integrating appointment management, point-of-sale (POS), inventory management, and sales monitoring into a single platform.

The application replaces manual and fragmented workflows with a centralized digital solution that improves operational efficiency, minimizes scheduling conflicts, maintains accurate inventory records, and simplifies clinic management across multiple branches.

---

## Purpose of the Application

The system is designed to improve the efficiency and organization of Luxuriskin Aesthetic Clinic's daily operations through an integrated management platform.

The application enables customers to conveniently book appointments by selecting their preferred branch, services, and schedule without creating an account. Authorized staff can manage appointments, process service and product transactions, and monitor inventory through an integrated Point-of-Sale (POS) system that automatically updates stock levels after every completed sale.

The clinic owner has full access to oversee operations, including user management, appointment management, inventory tracking, sales monitoring, and operational reporting. By maintaining all operational records in a centralized database, the system reduces manual work, prevents duplicate records, minimizes scheduling conflicts, and improves overall clinic efficiency.

---

## Problem Statement

Luxuriskin Aesthetic Clinic currently relies on separate and manual processes for managing appointments, customer records, inventory, and sales.

Current challenges include:

- Manual appointment scheduling
- Lack of centralized customer records
- Limited visibility across clinic branches
- Separate management of sales and inventory
- Manual inventory updates after transactions
- Inaccurate stock records
- Difficulty monitoring product availability
- Increased risk of scheduling conflicts and duplicate records

To address these issues, the system integrates appointment management, Point-of-Sale (POS), inventory management, and sales monitoring into one centralized application.

---

# Target Users

## Clinic Owner (Administrator)

The clinic owner has full administrative access to the system.

Responsibilities include:

- Manage staff accounts and permissions
- Configure Point-of-Sale (POS)
- Monitor sales transactions
- Track inventory
- Manage products and services
- View operational reports
- Manage customer records
- Confirm, update, reschedule, or cancel appointments

---

## Branch Manager

Branch managers have role-based access assigned by the clinic owner.

Responsibilities include:

- Process POS transactions
- Manage appointments
- Verify customer bookings
- Manage customer records
- Update appointment status
- Reschedule or cancel appointments

---

## Customers

Customers can access the appointment booking page without creating an account.

They can:

- Select their preferred branch
- Choose available services
- Select an appointment date and time
- Submit booking information

Once submitted, appointments are reviewed and managed by authorized clinic staff. The system automatically detects scheduling conflicts before confirming appointments.

---

# Project Objectives

## General Objective

Develop an integrated Aesthetic Clinic Management System for Luxuriskin Aesthetic Clinic.

## Specific Objectives

- Implement an appointment management system that allows customers to book appointments while enabling authorized staff to confirm, update, reschedule, cancel, and monitor appointments with automatic scheduling conflict detection.

- Develop a Point-of-Sale (POS) system that records service and product transactions while automatically updating inventory after every completed transaction.

- Automate inventory management by synchronizing inventory records with completed sales transactions and providing sales monitoring to improve stock management and business operations.

---

# Core Features

## Appointment Management

- Online appointment booking
- Branch selection
- Service selection
- Schedule selection
- Appointment confirmation
- Appointment rescheduling
- Appointment cancellation
- Conflict detection to prevent double bookings

---

## Point-of-Sale (POS)

- Record service transactions
- Record product sales
- Maintain transaction history
- Automatic inventory deduction

---

## Inventory Management

- Product inventory tracking
- Automatic stock updates
- Stock availability monitoring
- Inventory record management

---

## Sales Monitoring

- Sales history
- Transaction records
- Operational sales monitoring

---

# Scope

The system focuses on three integrated modules:

- Appointment Management
- Point-of-Sale (POS)
- Inventory Management

The Appointment Management module allows customers to book appointments by selecting their preferred branch, services, appointment date, and time without creating an account. Authorized staff and the clinic owner can review, confirm, update, reschedule, or cancel appointments while the system automatically detects scheduling conflicts.

The Point-of-Sale module records both service and product transactions and maintains transaction history.

The Inventory Management module is integrated with the POS system, automatically updating stock quantities after every completed transaction to ensure accurate inventory records.

---

# User Roles

| Role | Access |
|------|--------|
| Clinic Owner | Full system administration |
| Branch Manager | Appointment management and POS operations |
| Customer | Appointment booking |

---

# Limitations

The current version of the system **does not include**:

- Online payment processing
- Barcode scanning
- Receipt printing
- Supplier management
- Predictive analytics
- Artificial intelligence features
- Customer account registration
- Customer self-management of appointments after submission
- Dedicated mobile application

These features are outside the scope of the current study and may be considered for future development.

---

# Technologies

> *Update this section based on your actual technology stack.*

### Frontend

- Flutter
- Dart

### Backend

- Firebase Authentication
- Cloud Firestore

### Database

- Cloud Firestore

---

# Future Enhancements

Potential future improvements include:

- Online payment integration
- Receipt printing
- Barcode scanner support
- Supplier management
- Customer accounts
- Mobile application
- Analytics dashboard
- AI-assisted reporting
- Predictive analytics

---

# License

This project was developed as an undergraduate capstone project for academic purposes.

---

**Developed for:** Luxuriskin Aesthetic Clinic
