// PATH: ios-app/Rafiq/Features/Trips/
// FILENAME: TripCardView.swift

import SwiftUI

// ============================================================
// MARK: - TripCardView
// ============================================================

struct TripCardView: View {
    let trip: Trip

    var body: some View {
        AppCard(shadow: .medium) {
            VStack(spacing: RafiqSpacing.md) {
                // Route + Price header
                routeHeader

                // Timeline row
                timelineRow

                Divider()

                // Driver info
                driverRow

                Divider()

                // Bottom: Seats + Vehicle + Meeting mode
                bottomRow
            }
        }
    }

    // MARK: - Route Header

    private var routeHeader: some View {
        HStack(alignment: .top) {
            // Route
            VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                HStack(spacing: RafiqSpacing.sm) {
                    Circle()
                        .fill(RafiqColors.primaryFallback)
                        .frame(width: 8, height: 8)
                    Text(trip.originNameAr)
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                }

                // Dashed line
                Rectangle()
                    .fill(RafiqColors.textSecondaryFallback.opacity(0.3))
                    .frame(width: 1, height: 16)
                    .padding(.leading, 3.5)

                HStack(spacing: RafiqSpacing.sm) {
                    Circle()
                        .fill(RafiqColors.errorFallback)
                        .frame(width: 8, height: 8)
                    Text(trip.destNameAr)
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                }
            }

            Spacer()

            // Price badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(trip.formattedPrice)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(RafiqColors.primaryFallback)
                Text("للمقعد")
                    .font(RafiqFonts.small())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
            }
        }
    }

    // MARK: - Timeline Row

    private var timelineRow: some View {
        HStack(spacing: RafiqSpacing.lg) {
            // Date
            HStack(spacing: RafiqSpacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(RafiqColors.primaryFallback)
                Text(trip.tripDate.arabicShortDate)
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)
            }

            // Time
            HStack(spacing: RafiqSpacing.xs) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(RafiqColors.primaryFallback)
                Text(trip.tripDate.arabicTime)
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)
            }

            Spacer()

            // Relative time
            Text(trip.tripDate.arabicRelative)
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.accentFallback)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RafiqColors.accentFallback.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: - Driver Row

    private var driverRow: some View {
        HStack(spacing: RafiqSpacing.md) {
            // Avatar
            Image(systemName: "person.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.driverName)
                    .font(RafiqFonts.bodyBold())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)

                HStack(spacing: RafiqSpacing.sm) {
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(RafiqColors.warningFallback)
                        Text(String(format: "%.1f", trip.driverRating))
                            .font(RafiqFonts.caption())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                    }

                    // Vehicle
                    Text("·")
                        .foregroundStyle(RafiqColors.textSecondaryFallback)

                    Text(trip.vehicleSummary)
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack(spacing: RafiqSpacing.md) {
            // Available seats
            infoChip(
                icon: "person.3.fill",
                text: "\(trip.availableSeats) مقعد",
                color: trip.availableSeats > 0 ? RafiqColors.successFallback : RafiqColors.errorFallback
            )

            // Meeting mode
            infoChip(
                icon: trip.meetingMode.icon,
                text: trip.meetingMode.displayName,
                color: RafiqColors.primaryFallback
            )

            Spacer()

            // Status badge
            statusBadge
        }
    }

    private func infoChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(RafiqFonts.small())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var statusBadge: some View {
        let (text, color) = statusDisplay(trip.status)
        return Text(text)
            .font(RafiqFonts.small())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func statusDisplay(_ status: TripStatus) -> (String, Color) {
        switch status {
        case .open: return ("متاح", RafiqColors.successFallback)
        case .full: return ("مكتمل", RafiqColors.warningFallback)
        case .inProgress: return ("جارية", RafiqColors.accentFallback)
        case .completed: return ("منتهية", RafiqColors.textSecondaryFallback)
        case .cancelled: return ("ملغية", RafiqColors.errorFallback)
        }
    }
}

// ============================================================
// MARK: - Compact Card Variant (for lists / horizontal scroll)
// ============================================================

struct TripCardCompact: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
            // Route
            Text(trip.routeText)
                .font(RafiqFonts.bodyBold())
                .foregroundStyle(RafiqColors.textPrimaryFallback)
                .lineLimit(1)

            // Date + Time
            Text(trip.tripDate.arabicShortDate + " · " + trip.tripDate.arabicTime)
                .font(RafiqFonts.caption())
                .foregroundStyle(RafiqColors.textSecondaryFallback)

            HStack {
                // Price
                Text(trip.formattedPrice)
                    .font(RafiqFonts.heading3())
                    .foregroundStyle(RafiqColors.primaryFallback)

                Spacer()

                // Seats
                HStack(spacing: 3) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 10))
                    Text("\(trip.availableSeats)")
                        .font(RafiqFonts.small())
                }
                .foregroundStyle(RafiqColors.successFallback)
            }
        }
        .padding(RafiqSpacing.md)
        .frame(width: 200)
        .background(RafiqColors.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
        .rafiqShadow(.light)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Trip Card - Full") {
    ScrollView {
        VStack(spacing: RafiqSpacing.md) {
            TripCardView(trip: .mock)

            TripCardView(trip: Trip.mockList[1])
        }
        .padding()
    }
    .background(RafiqColors.backgroundFallback)
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Trip Card - Compact") {
    ScrollView(.horizontal) {
        HStack(spacing: RafiqSpacing.md) {
            TripCardCompact(trip: .mock)
            TripCardCompact(trip: Trip.mockList[1])
        }
        .padding()
    }
    .background(RafiqColors.backgroundFallback)
    .environment(\.layoutDirection, .rightToLeft)
}
