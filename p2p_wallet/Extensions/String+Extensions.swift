//
//  String+Extensions.swift
//  p2p wallet
//
//  Created by Chung Tran on 10/23/20.
//

import Down
import FirebaseRemoteConfig
import Foundation

extension Optional where Wrapped == String {
    public var orEmpty: String {
        self ?? ""
    }

    static func + (left: String?, right: String?) -> String {
        left.orEmpty + right.orEmpty
    }
}

extension String {
    var firstCharacter: String {
        String(prefix(1))
    }

    public var uppercaseFirst: String {
        firstCharacter.uppercased() + String(dropFirst())
    }

    public func onlyUppercaseFirst() -> String {
        lowercased().uppercaseFirst
    }

    // swiftlint:disable swiftgen_strings
    func localized() -> String {
        NSLocalizedString(self, comment: "")
    }

    // swiftlint:enable swiftgen_strings

    func truncatingMiddle(numOfSymbolsRevealed: Int = 4, numOfSymbolsRevealedInSuffix: Int? = nil) -> String {
        if count <= numOfSymbolsRevealed + (numOfSymbolsRevealedInSuffix ?? numOfSymbolsRevealed) { return self }
        return prefix(numOfSymbolsRevealed) + "..." + suffix(numOfSymbolsRevealedInSuffix ?? numOfSymbolsRevealed)
    }


    static var nameServiceDomain: String {
        RemoteConfig.remoteConfig().usernameDomain ?? "key"
    }

    static func secretConfig(_ key: String) -> String? {
        Bundle.main.infoDictionary?[key] as? String
    }
}

extension String {
    // TODO: Deprecate this getter. Use directly Double(string).
    var double: Double? {
        Double(self)
    }
}

extension String {
    func asMarkdown(textSize: CGFloat? = nil, textColor: UIColor? = nil) -> NSAttributedString {
        let down = Down(markdownString: self)

        let fonts = StaticFontCollection(
            body: UIFont.systemFont(ofSize: textSize ?? 15)
        )

        let colors = StaticColorCollection(
            body: textColor ?? UIColor.textBlack
        )

        var paragraph = StaticParagraphStyleCollection()
        paragraph.body = {
            let p = NSMutableParagraphStyle()
            p.lineSpacing = 0
            return p
        }()

        return (try? down.toAttributedString(styler: DownStyler(
            configuration: DownStylerConfiguration(
                fonts: fonts,
                colors: colors,
                paragraphStyles: paragraph
            )
        ))) ?? NSAttributedString()
    }
}

extension Collection {
    func unfoldSubSequences(limitedTo maxLength: Int) -> UnfoldSequence<SubSequence, Index> {
        sequence(state: startIndex) { start in
            guard start < endIndex else { return nil }
            let end = index(start, offsetBy: maxLength, limitedBy: endIndex) ?? endIndex
            defer { start = end }
            return self[start ..< end]
        }
    }

    func every(n: Int) -> UnfoldSequence<Element, Index> {
        sequence(state: startIndex) { index in
            guard index < endIndex else { return nil }
            defer { _ = formIndex(&index, offsetBy: n, limitedBy: endIndex) }
            return self[index]
        }
    }

    var pairs: [SubSequence] { .init(unfoldSubSequences(limitedTo: 2)) }
}

extension StringProtocol where Self: RangeReplaceableCollection {
    mutating func insert<S: StringProtocol>(separator: S, every n: Int) {
        for index in indices.every(n: n).dropFirst().reversed() {
            insert(contentsOf: separator, at: index)
        }
    }

    func inserting<S: StringProtocol>(separator: S, every n: Int) -> Self {
        .init(unfoldSubSequences(limitedTo: n).joined(separator: separator))
    }
}

// MARK: - Amount formatting

extension String {
    var fiatFormat: String {
        formatToMoneyFormat(decimalSeparator: ".", maxDecimals: 2)
    }

    var cryptoCurrencyFormat: String {
        formatToMoneyFormat(decimalSeparator: ".", maxDecimals: 9)
    }

    var withoutLastZeros: String {
        var formatted = self
        while formatted.last == "." || formatted.last == "," || formatted.last == "0" {
            if !formatted.contains(","), !formatted.contains(".") {
                return formatted
            }
            formatted.removeLast()
        }
        return formatted
    }

    func formatToMoneyFormat(decimalSeparator: String, maxDecimals: UInt) -> String {
        var formatted = replacingOccurrences(of: ",", with: decimalSeparator)
            .replacingOccurrences(of: ".", with: decimalSeparator)
            .nonLetters(decimalSeparator: decimalSeparator)
        let components = formatted.components(separatedBy: decimalSeparator)
        let intPart = components[0]
        let withoutFirstZeros = intPart.count > 1 || intPart.isEmpty ? "\(Int(intPart) ?? 0)" : intPart
        if components.count >= 2 {
            let maxFormatted = components[1].prefix(Int(maxDecimals))
            formatted = "\(withoutFirstZeros)\(decimalSeparator)\(maxFormatted)"
            return formatted
        } else {
            return withoutFirstZeros
        }
    }

    private func nonLetters(decimalSeparator: String) -> String { filter("0123456789\(decimalSeparator)".contains) }

    var formatApy: String {
        guard let apyDouble = Double(self) else { return "" }
        return "\(apyDouble.fixedDecimal(2))%".replacingOccurrences(of: ",", with: ".")
    }
}

extension String {
    var isPhoneNumber: Bool {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
            let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: count))
            if let res = matches.first {
                return res.resultType == .phoneNumber && res.range.location == 0 && res.range.length == count
            } else {
                return false
            }
        } catch {
            return false
        }
    }
}

extension String {
    func separate(every: Int, with separator: String) -> String {
        String(stride(from: 0, to: Array(self).count, by: every).map {
            Array(Array(self)[$0 ..< min($0 + every, Array(self).count)])
        }.joined(separator: separator))
    }

    func firstUppercased() -> String {
        prefix(1).uppercased() + dropFirst()
    }
}

extension String {
    var snakeAndFirstUppercased: String? {
        guard let snakeCase = snakeCased() else { return nil }
        return snakeCase.prefix(1).uppercased() + snakeCase.dropFirst()
    }
    
    func snakeCased() -> String? {
        let pattern = "([a-z0-9])([A-Z])"

        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: count)
        return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
            .uppercaseFirst
    }
}

extension String {
    static var fakeTransactionSignaturePrefix: String {
        "<FakeTransactionSignature>"
    }
    
    static func fakeTransactionSignature(id: String) -> String {
        fakeTransactionSignaturePrefix + "<\(id)>"
    }
}

// MARK: - Flag

extension String {
    var asFlag: String? {
        let base : UInt32 = 127397
        var s = ""
        unicodeScalars.forEach {
            s.unicodeScalars.append(UnicodeScalar(base + $0.value)!)
        }
        return String(s)
    }
}
