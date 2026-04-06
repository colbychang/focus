import Foundation

// MARK: - TrendType

/// The classification of a data trend.
public enum TrendType: String, Codable, Equatable, Sendable {
    /// Data shows a sustained increasing pattern.
    case increasing
    /// Data shows a sustained decreasing pattern.
    case decreasing
    /// Data is relatively flat with normal variance.
    case stable
    /// Not enough data to determine a trend (fewer than minimum data points).
    case undetermined
}

// MARK: - SpikeInfo

/// Information about a detected usage spike.
public struct SpikeInfo: Equatable, Sendable {
    /// The index of the spike in the data array.
    public let index: Int
    /// The actual value at the spike.
    public let value: Double
    /// The 7-day moving average at the time of the spike.
    public let movingAverage: Double
    /// The ratio of value to moving average.
    public let ratio: Double

    public init(index: Int, value: Double, movingAverage: Double, ratio: Double) {
        self.index = index
        self.value = value
        self.movingAverage = movingAverage
        self.ratio = ratio
    }
}

// MARK: - TrendResult

/// The result of trend analysis on a data array.
public struct TrendResult: Equatable, Sendable {
    /// The overall trend classification.
    public let trend: TrendType
    /// Any detected spikes in the data.
    public let spikes: [SpikeInfo]

    public init(trend: TrendType, spikes: [SpikeInfo] = []) {
        self.trend = trend
        self.spikes = spikes
    }
}

// MARK: - TrendDetectorConfig

/// Configuration for the trend detector with adjustable thresholds.
public struct TrendDetectorConfig: Sendable {
    /// Minimum number of data points required to determine a trend.
    /// Below this, result is `.undetermined`.
    public let minimumDataPoints: Int

    /// The window size for computing the moving average (used for spike detection).
    public let movingAverageWindow: Int

    /// The multiplier threshold for spike detection.
    /// A value is flagged as a spike if it exceeds `spikeThreshold × movingAverage`.
    public let spikeThreshold: Double

    /// The minimum fraction of consecutive increases needed to classify as `.increasing`.
    /// E.g., 0.6 means at least 60% of data-point transitions must be increases.
    public let increasingThreshold: Double

    /// The minimum fraction of consecutive decreases needed to classify as `.decreasing`.
    public let decreasingThreshold: Double

    /// Creates a trend detector configuration.
    ///
    /// - Parameters:
    ///   - minimumDataPoints: Minimum data points required (default: 7).
    ///   - movingAverageWindow: Window for moving average (default: 7).
    ///   - spikeThreshold: Multiplier for spike detection (default: 2.0).
    ///   - increasingThreshold: Fraction threshold for increasing trend (default: 0.6).
    ///   - decreasingThreshold: Fraction threshold for decreasing trend (default: 0.6).
    public init(
        minimumDataPoints: Int = 7,
        movingAverageWindow: Int = 7,
        spikeThreshold: Double = 2.0,
        increasingThreshold: Double = 0.6,
        decreasingThreshold: Double = 0.6
    ) {
        self.minimumDataPoints = minimumDataPoints
        self.movingAverageWindow = movingAverageWindow
        self.spikeThreshold = spikeThreshold
        self.increasingThreshold = increasingThreshold
        self.decreasingThreshold = decreasingThreshold
    }

    /// The default configuration.
    public static let `default` = TrendDetectorConfig()
}

// MARK: - TrendDetector

/// Analyzes data arrays to detect trends (increasing, decreasing, stable)
/// and identify usage spikes.
///
/// Rules:
/// - Requires at least `config.minimumDataPoints` (default 7) data points.
/// - Classifies trend based on the fraction of increasing/decreasing transitions.
/// - Spike detection: flags values exceeding `config.spikeThreshold × movingAverage`.
/// - Moving average uses a rolling window of `config.movingAverageWindow` (default 7) points.
/// - Configurable thresholds for all parameters.
public struct TrendDetector: Sendable {

    // MARK: - Configuration

    /// The configuration for this detector.
    public let config: TrendDetectorConfig

    // MARK: - Initialization

    /// Creates a TrendDetector with the given configuration.
    ///
    /// - Parameter config: The configuration to use (default: `.default`).
    public init(config: TrendDetectorConfig = .default) {
        self.config = config
    }

    // MARK: - Analyze

    /// Analyzes a data array and returns the trend classification and any spikes.
    ///
    /// - Parameter data: An array of numeric values (e.g., daily usage durations in seconds).
    /// - Returns: A `TrendResult` with the trend type and any detected spikes.
    public func analyze(_ data: [Double]) -> TrendResult {
        // Insufficient data → undetermined
        guard data.count >= config.minimumDataPoints else {
            return TrendResult(trend: .undetermined)
        }

        // Detect spikes
        let spikes = detectSpikes(data)

        // Classify trend
        let trend = classifyTrend(data)

        return TrendResult(trend: trend, spikes: spikes)
    }

    // MARK: - Trend Classification

    /// Classifies the overall trend direction of the data.
    ///
    /// Counts the number of increasing and decreasing transitions between
    /// consecutive data points. If the fraction of increases exceeds the
    /// `increasingThreshold`, classifies as `.increasing`. Similarly for
    /// `.decreasing`. Otherwise, `.stable`.
    private func classifyTrend(_ data: [Double]) -> TrendType {
        guard data.count >= 2 else { return .stable }

        var increases = 0
        var decreases = 0
        let totalTransitions = data.count - 1

        for i in 0..<totalTransitions {
            if data[i + 1] > data[i] {
                increases += 1
            } else if data[i + 1] < data[i] {
                decreases += 1
            }
            // Equal values don't count as either
        }

        let increaseFraction = Double(increases) / Double(totalTransitions)
        let decreaseFraction = Double(decreases) / Double(totalTransitions)

        if increaseFraction >= config.increasingThreshold {
            return .increasing
        } else if decreaseFraction >= config.decreasingThreshold {
            return .decreasing
        } else {
            return .stable
        }
    }

    // MARK: - Spike Detection

    /// Detects spikes in the data where a value exceeds the moving average
    /// by a factor of `config.spikeThreshold`.
    ///
    /// Only checks data points that have at least `movingAverageWindow` prior values
    /// available for computing the moving average.
    private func detectSpikes(_ data: [Double]) -> [SpikeInfo] {
        let window = config.movingAverageWindow
        guard data.count > window else { return [] }

        var spikes: [SpikeInfo] = []

        for i in window..<data.count {
            // Compute the moving average of the preceding `window` values
            let windowSlice = data[(i - window)..<i]
            let movingAvg = windowSlice.reduce(0, +) / Double(window)

            // A moving average of 0 means no prior usage; skip to avoid false positives
            guard movingAvg > 0 else { continue }

            let ratio = data[i] / movingAvg

            if ratio > config.spikeThreshold {
                spikes.append(SpikeInfo(
                    index: i,
                    value: data[i],
                    movingAverage: movingAvg,
                    ratio: ratio
                ))
            }
        }

        return spikes
    }
}
