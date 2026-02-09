import AppKit
import Foundation
import SwiftUI

enum OnboardingLegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String {
        self.rawValue
    }

    var resourceBaseName: String {
        switch self {
        case .terms:
            "terms-of-service"
        case .privacy:
            "privacy-policy"
        }
    }
}

extension OnboardingView {
    func legalDocumentSheet(for document: OnboardingLegalDocument) -> some View {
        let markdown = self.legalDocumentText(for: document)
        let rendered = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(self.legalTitle(for: document))
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
                Button {
                    self.presentedLegalDocument = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                Text(rendered)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    private func legalTitle(for document: OnboardingLegalDocument) -> String {
        switch document {
        case .terms:
            self.t(.termsOfService)
        case .privacy:
            self.t(.privacyPolicy)
        }
    }

    private func legalDocumentText(for document: OnboardingLegalDocument) -> String {
        for candidate in self.legalResourceCandidates(for: document) {
            if let text = self.readBundledLegalResource(named: candidate) {
                return text
            }
        }
        return "Document unavailable."
    }

    private func legalResourceCandidates(for document: OnboardingLegalDocument) -> [String] {
        let base = document.resourceBaseName
        switch self.onboardingLanguage {
        case .zhHans:
            return ["\(base).zh-CN", base]
        case .zhHant:
            return ["\(base).zh-TW", "\(base).zh-CN", base]
        case .ja:
            return ["\(base).ja", base]
        case .en:
            return [base]
        }
    }

    private func readBundledLegalResource(named resourceName: String) -> String? {
        guard let bundle = Self.legalResourceBundle else { return nil }
        guard let url = bundle.url(forResource: resourceName, withExtension: "md", subdirectory: "Legal") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static var legalResourceBundle: Bundle? {
        self.locateLegalResourceBundle()
    }

    private static func locateLegalResourceBundle() -> Bundle? {
        if self.bundleContainsLegalResources(Bundle.main) {
            return Bundle.main
        }
        if self.bundleContainsLegalResources(Bundle.module) {
            return Bundle.module
        }
        return nil
    }

    private static func bundleContainsLegalResources(_ bundle: Bundle) -> Bool {
        bundle.url(forResource: "terms-of-service", withExtension: "md", subdirectory: "Legal") != nil
            && bundle.url(forResource: "privacy-policy", withExtension: "md", subdirectory: "Legal") != nil
    }
}
