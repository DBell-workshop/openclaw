import OpenClawProtocol
import Observation
import SwiftUI

extension OnboardingView {
    func wizardPage() -> some View {
        self.onboardingPage {
            VStack(spacing: 16) {
                Text(self.t(.setupWizardTitle))
                    .font(.largeTitle.weight(.semibold))
                Text(self.t(.setupWizardSubtitle))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)

                self.onboardingCard(spacing: 14, padding: 16) {
                    OnboardingWizardCardContent(
                        wizard: self.onboardingWizard,
                        mode: self.state.connectionMode,
                        workspacePath: self.workspacePath,
                        lang: self.onboardingLanguage)
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
    let lang: OnboardingLanguage

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
            Text(OnboardingCopy.text(.wizardError, lang: self.lang))
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if self.wizard.needsEnableAutostart {
                HStack(spacing: 10) {
                    Button(OnboardingCopy.text(.enableAutostart, lang: self.lang)) {
                        Task {
                            await self.wizard.enableAutostartAndRetry(
                                mode: self.mode,
                                workspace: self.workspacePath.isEmpty ? nil : self.workspacePath)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(OnboardingCopy.text(.retry, lang: self.lang)) {
                        self.wizard.reset()
                        Task {
                            await self.wizard.startIfNeeded(
                                mode: self.mode,
                                workspace: self.workspacePath.isEmpty ? nil : self.workspacePath)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button(OnboardingCopy.text(.retry, lang: self.lang)) {
                    self.wizard.reset()
                    Task {
                        await self.wizard.startIfNeeded(
                            mode: self.mode,
                            workspace: self.workspacePath.isEmpty ? nil : self.workspacePath)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        case .starting:
            HStack(spacing: 8) {
                ProgressView()
                VStack(alignment: .leading, spacing: 2) {
                    Text(OnboardingCopy.text(.gatewayDepsInstallingTitle, lang: self.lang))
                        .foregroundStyle(.secondary)
                    Text(OnboardingCopy.text(.gatewayDepsInstallingSubtitle, lang: self.lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            Text(OnboardingCopy.text(.wizardComplete, lang: self.lang))
                .font(.headline)
        case .waiting:
            Text(OnboardingCopy.text(.waitingWizard, lang: self.lang))
                .foregroundStyle(.secondary)
        }
    }
}
