import Foundation
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
class AIAdvisor: ObservableObject {
    @Published var adviceText: String = ""
    @Published var isGenerating: Bool = false

    func generateAdvice(processes: [ProcessInfo]) {
        guard !isGenerating else { return }
        isGenerating = true
        adviceText = ""

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            Task {
                await performGeneration(processes: processes)
            }
            return
        }
        #endif

        adviceText = "AI Advice requires macOS 26 or later with Apple Intelligence enabled."
        isGenerating = false
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func performGeneration(processes: [ProcessInfo]) async {
        do {
            let session = LanguageModelSession(instructions: """
                You are a concise macOS system performance advisor. \
                Analyze the given process data and provide actionable tips \
                to help the user optimize their Mac's performance. \
                Be brief, clear, and practical. Use plain language.
                """)

            let prompt = buildPrompt(from: processes)
            let stream = session.streamResponse(to: prompt)

            for try await partial in stream {
                self.adviceText = partial.content
            }

            self.isGenerating = false
        } catch {
            self.adviceText = "Unable to generate advice: \(error.localizedDescription)"
            self.isGenerating = false
        }
    }
    #endif

    private func buildPrompt(from processes: [ProcessInfo]) -> String {
        let topCPU = Array(processes.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(8))
        let topMem = Array(processes.sorted { $0.memory > $1.memory }.prefix(5))

        var lines: [String] = ["Top CPU-consuming processes:"]
        for p in topCPU {
            lines.append("  \(p.name) (PID \(p.processID)): CPU \(String(format: "%.1f", p.cpuUsage))%, Memory \(String(format: "%.0f", p.memory)) MB")
        }
        lines.append("")
        lines.append("Top memory-consuming processes:")
        for p in topMem {
            lines.append("  \(p.name) (PID \(p.processID)): Memory \(String(format: "%.0f", p.memory)) MB, CPU \(String(format: "%.1f", p.cpuUsage))%")
        }
        lines.append("")
        lines.append("Total processes running: \(processes.count)")
        lines.append("")
        lines.append("Based on this snapshot, give the user up to 3 brief, actionable tips to optimize their Mac's performance right now. No need for greetings or markdown headers. Concise as possible")
		lines.append(" Example format: '1.\n2.\n3.'")

        return lines.joined(separator: "\n")
    }
}
