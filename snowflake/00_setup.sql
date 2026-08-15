-- ============================================================================
-- Zakat & Waqf Management
-- Data-driven zakat collection and distribution for Indonesia's US$14B potential — ML.FORECAST predicts collection trends, Dynamic Tables build real-time muzakki/mustahik dashboards, and Cortex AI generates impact reports.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS ZAKAT_MANAGEMENT;
CREATE WAREHOUSE IF NOT EXISTS ZAKAT_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE ZAKAT_MANAGEMENT;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE ZAKAT_WH;
