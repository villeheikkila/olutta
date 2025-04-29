import Logging
import SwiftLogTelegram

func buildLogger(label: String, telegramApiKey: String, telegramErrorChatId: String, logLevel: Logger.Level) -> Logger {
    LoggingSystem.bootstrap { label in
        MultiplexLogHandler([
            TelegramLogHandler(label: label, token: telegramApiKey, chatId: telegramErrorChatId, onTelegeramError: { error in
                print("failed to send message to telegram: \(error)")
            }),
            StreamLogHandler.standardOutput(label: label),
        ])
    }
    var logger = Logger(label: label)
    logger.logLevel = logLevel
    return logger
}
