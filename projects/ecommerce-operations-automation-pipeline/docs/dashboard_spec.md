# Operations Dashboard Specification

## Executive Header

- Daily GMV
- Daily Order Count
- Average Order Value
- Fulfillment Rate
- Delayed Shipment Count
- Data Error Count

## Operational Panels

1. **Sales Pulse:** GMV, orders and AOV by date with campaign shading.
2. **Order Status:** Completed, processing, cancelled, refunded and invalid status mix.
3. **Fulfillment Watch:** Delayed orders by promised date and region.
4. **Inventory Risk:** Low-stock products prioritized by sales rank.
5. **Product Monitor:** GMV rank and recent-period decline alerts.
6. **Data Quality:** Error counts by rule, source and severity.

## Filters

- Date range
- Region
- Product category
- Campaign
- Alert severity and type

## Refresh Contract

- Daily target refresh: 07:00.
- Dashboard publishes only after extract, transform and validate succeed.
- Data errors remain visible even when valid records continue through the MVP.
- Production mode should block publication when critical thresholds are exceeded.
