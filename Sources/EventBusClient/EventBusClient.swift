import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct EventBusClient: Sendable {
    public var publish: @Sendable (_ event: any Sendable) async -> Void
    public var subscribe: @Sendable () async -> AsyncStream<any Sendable> = { .finished }
}

extension EventBusClient: DependencyKey {
    public static let liveValue: EventBusClient = {
        let actor = EventBusClientActor()
        return EventBusClient(
            publish: { event in
                await actor.publish(event)
            },
            subscribe: {
                await actor.subscribe()
            }
        )
    }()
    
    public static let testValue: EventBusClient = {
        let actor = EventBusClientActor()
        return EventBusClient(
            publish: { event in
                await actor.publish(event)
            },
            subscribe: {
                await actor.subscribe()
            }
        )
    }()
}

extension DependencyValues {
    public var eventBusClient: EventBusClient {
        get { self[EventBusClient.self] }
        set { self[EventBusClient.self] = newValue }
    }
}

private actor EventBusClientActor {
    private var subscribers: [UUID: AsyncStream<any Sendable>.Continuation] = [:]
    deinit {
        for subscriber in subscribers.values {
            subscriber.finish()
        }
    }
    func publish(_ event: any Sendable) -> Void {
        for subscriber in subscribers.values {
            subscriber.yield(event)
        }
    }
    func subscribe() -> AsyncStream<any Sendable> {
        AsyncStream { continuation in
            let id = UUID()
            self.subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(id)
                }
            }
        }
    }
    private func removeContinuation(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }
}
