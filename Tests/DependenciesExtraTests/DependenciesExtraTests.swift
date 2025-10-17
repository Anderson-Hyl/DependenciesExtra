import Dependencies
import Testing
import SnapshotTesting
@testable import EventBusClient

@MainActor
struct EventBusClientTests {
    @Test func publishAndSubscribe() async throws {
        @Dependency(\.eventBusClient) var client
        let streamA = await client.subscribe()
        let streamB = await client.subscribe()
        await withTaskGroup(of: String.self) { group in
            group.addTask {
                await self.snapshotEvents(streamA, expectedCount: 3)
            }
            group.addTask {
                await self.snapshotEvents(streamB, expectedCount: 3)
            }
            
            try? await Task.sleep(for: .milliseconds(10))
                        
            // 3. 发布事件 (在主任务中发布)
            await client.publish("Event 1: Start")
            await client.publish("Event 2: Middle")
            await client.publish("Event 3: End")
            
            // 4. 收集结果
            var results: [String] = []
            for await result in group {
                results.append(result)
            }
            let finalSnapshot = results.sorted().joined(separator: "\n---\n")
                        
            // 使用 .lines 快照来验证字符串内容
            assertSnapshot(of: finalSnapshot, as: .lines)
        }
    }
    
    func snapshotEvents(
            _ eventStream: AsyncStream<any Sendable>,
            expectedCount: Int
        ) async -> String {
            var receivedEvents: [String] = []
            var count = 0
            
            // 限制循环次数，避免无限等待
            for await event in eventStream {
                // 将事件转换为可读的字符串（需要处理 any Sendable）
                // 假设你的事件是简单的结构体或字符串
                let description: String
                if let stringEvent = event as? String {
                    description = stringEvent
                } else {
                    description = "<\(type(of: event))>"
                }
                receivedEvents.append(description)
                count += 1
                
                if count >= expectedCount {
                    break
                }
            }
            
            return "Received Events:\n" + receivedEvents.joined(separator: "\n")
        }
}
