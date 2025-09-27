import Foundation
import SwiftUI

struct MessageIdentifierObserverModifier<ID>: ViewModifier
    where ID: NotificationCenter.MessageIdentifier,
    ID.MessageType: NotificationCenter.MainActorMessage,
    ID.MessageType.Subject: AnyObject
{
    let messageID: ID
    let subject: ID.MessageType.Subject?
    let perform: (ID.MessageType) -> Void
    @State var token: NotificationCenter.ObservationToken?
    init(
        messageID: ID,
        subject: ID.MessageType.Subject?,
        perform: @escaping (ID.MessageType) -> Void,
    ) {
        self.messageID = messageID
        self.subject = subject
        self.perform = perform
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard token == nil else { return }
                if let subject {
                    token = NotificationCenter.default.addObserver(
                        of: subject,
                        for: messageID,
                    ) { perform($0)
                    }
                } else {
                    token = NotificationCenter.default.addObserver(
                        of: subject,
                        for: ID.MessageType.self,
                    ) { perform($0)
                    }
                }
            }
            .onDisappear {
                if let t = token {
                    NotificationCenter.default.removeObserver(t)
                }
            }
    }
}

struct MessageTypeObserverModifier<Message>: ViewModifier
    where Message: NotificationCenter.MainActorMessage,
    Message.Subject: AnyObject
{
    let messageType: Message.Type
    let subject: Message.Subject?
    let perform: (Message) -> Void

    @State private var token: NotificationCenter.ObservationToken?

    init(
        messageType: Message.Type,
        subject: Message.Subject? = nil,
        perform: @escaping (Message) -> Void,
    ) {
        self.messageType = messageType
        self.subject = subject
        self.perform = perform
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard token == nil else { return }
                token = NotificationCenter.default.addObserver(
                    of: subject,
                    for: messageType,
                    using: perform,
                )
            }
            .onDisappear {
                if let t = token {
                    NotificationCenter.default.removeObserver(t)
                    token = nil
                }
            }
    }
}

extension View {
    func onReceive<Message>(
        of messageType: Message.Type,
        subject: Message.Subject? = nil,
        perform: @escaping (Message) -> Void,
    ) -> some View
        where Message: NotificationCenter.MainActorMessage,
        Message.Subject: AnyObject
    {
        modifier(
            MessageTypeObserverModifier(
                messageType: messageType,
                subject: subject,
                perform: perform,
            ))
    }
}

extension View {
    func onReceive<ID>(
        for messageID: ID,
        subject: ID.MessageType.Subject? = nil,
        perform: @escaping (ID.MessageType) -> Void,
    ) -> some View
        where
        ID: NotificationCenter.MessageIdentifier,
        ID.MessageType: NotificationCenter.MainActorMessage,
        ID.MessageType.Subject: AnyObject
    {
        modifier(MessageIdentifierObserverModifier(
            messageID: messageID,
            subject: subject,
            perform: perform,
        ))
    }
}

public extension NotificationCenter {
    struct PushNotificationTokenObtained: MainActorMessage {
        public typealias Subject = PushNotificationManager

        public static var name: Notification.Name {
            .init("PushNotifications.TokenObtained")
        }

        public let token: String
    }
}

public class PushNotificationManager {
    static let shared = PushNotificationManager()
}

extension NotificationCenter.MessageIdentifier
    where Self == NotificationCenter.BaseMessageIdentifier<NotificationCenter.PushNotificationTokenObtained>
{
    static var pushNotificationTokenObtained: Self { .init() }
}
