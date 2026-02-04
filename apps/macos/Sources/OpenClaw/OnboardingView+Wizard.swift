import OpenClawProtocol
import Observation
import SwiftUI

extension OnboardingView {
    func wizardPage() -> some View {
        let gatewayManager = GatewayProcessManager.shared
        return self.onboardingPage {
            VStack(spacing: 16) {
                Text(self.t(.setupWizardTitle))
                    .font(.largeTitle.weight(.semibold))
                Text(self.t(.setupWizardSubtitle))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)

                if let installMessage = gatewayManager.dependencyBootstrapMessage {
                    self.onboardingCard(spacing: 10, padding: 14) {
                        HStack(alignment: .top, spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(self.t(.gatewayDepsInstallingTitle))
                                    .font(.headline)
                                Text(self.t(.gatewayDepsInstallingSubtitle))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(installMessage)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                self.onboardingCard(spacing: 14, padding: 16) {
                    OnboardingWizardCardContent(
                        wizard: self.onboardingWizard,
                        mode: self.state.connectionMode,
                        workspacePath: self.workspacePath,
                        language: self.onboardingLanguage)
                }
            }
            .task {
                await self.onboardingWizard.startIfNeeded(
                    mode: self.state.connectionMode,
                    workspace: self.workspacePath.isEmpty ? nil : self.workspacePath)
            }
        }
    }
}

private struct OnboardingWizardCardContent: View {
    @Bindable var wizard: OnboardingWizardModel
    let mode: AppState.ConnectionMode
    let workspacePath: String
    let language: OnboardingLanguage

    private enum CardState {
        case error(String)
        case starting
        case step(WizardStep)
        case complete
        case waiting
    }

    private var state: CardState {
        if let error = wizard.errorMessage { return .error(error) }
        if self.wizard.isStarting { return .starting }
        if let step = wizard.currentStep { return .step(step) }
        if self.wizard.isComplete { return .complete }
        return .waiting
    }

    var body: some View {
        switch self.state {
        case let .error(error):
            Text(self.t(.wizardError))
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(self.t(.retry)) {
                self.wizard.reset()
                Task {
                    await self.wizard.startIfNeeded(
                        mode: self.mode,
                        workspace: self.workspacePath.isEmpty ? nil : self.workspacePath)
                }
            }
            .buttonStyle(.borderedProminent)
        case .starting:
            HStack(spacing: 8) {
                ProgressView()
                Text(self.t(.startingWizard))
                    .foregroundStyle(.secondary)
            }
        case let .step(step):
            OnboardingWizardStepView(
                step: step,
                isSubmitting: self.wizard.isSubmitting)
            { value in
                Task { await self.wizard.submit(step: step, value: value) }
            }
            .id(step.id)
        case .complete:
            Text(self.t(.wizardComplete))
                .font(.headline)
        case .waiting:
            Text(self.t(.waitingWizard))
                .foregroundStyle(.secondary)
        }
    }

    private func t(_ key: OnboardingCopyKey) -> String {
        OnboardingCopy.text(key, lang: self.language)
    }
}
