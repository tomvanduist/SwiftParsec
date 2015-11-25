//
//  Error.swift
//  SwiftParsec
//
//  Created by David Dufresne on 2015-09-04.
//  Copyright © 2015 David Dufresne. All rights reserved.
//
// Parse errors.
//

import Foundation

/// Message represents parse error messages. The fine distinction between different kinds of parse errors allows the system to generate quite good error messages for the user. It also allows error messages that are formatted in different languages. Each kind of message is generated by different combinators.
///
/// The `Comparable` protocol is implemented based on the index of a message.
public enum Message: Comparable {
    
    /// A `SystemUnexpected` message is automatically generated by the  `satisfy` combinator. The argument is the unexpected input.
    case SystemUnexpected(String)
    
    /// An `Unexpected` message is generated by the `unexpected` combinator. The argument describes the unexpected item.
    case Unexpected(String)
    
    /// An `Expect` message is generated by the `<?>` combinator. The argument describes the expected item.
    case Expected(String)
    
    /// A `Generic` message is generated by the `fail` combinator. The argument is some general parser message.
    case Generic(String)
    
    /// The index of the message type.
    var index: Int {
        
        switch self {
            
        case .SystemUnexpected: return 0
            
        case .Unexpected: return 1
            
        case .Expected: return 2
            
        case .Generic: return 3
            
        }
        
    }
    
    /// The message string.
    var messageString: String {
        
        switch self {
            
        case .SystemUnexpected(let str): return str
            
        case .Unexpected(let str): return str
        
        case .Expected(let str): return str
        
        case .Generic(let str): return str
            
        }
        
    }
    
}

/// Equality based on the index.
public func ==(leftMsg: Message, rightMsg: Message) -> Bool {
    
    return leftMsg.index == rightMsg.index
    
}

/// Comparison based on the index.
public func <(leftMsg: Message, rightMsg: Message) -> Bool {
    
    return leftMsg.index < rightMsg.index
    
}

/// `ParseError` represents parse errors. It provides the source position (`SourcePosition`) of the error and an array of error messages (`Message`). A `ParseError` can be returned by the function `parse`.
public struct ParseError: ErrorType, CustomStringConvertible {
    
    /// Return an unknown parse error.
    ///
    /// - parameter position: The current position.
    /// - returns: An unknown parse error.
    static func unknownParseError(position: SourcePosition) -> ParseError {
        
        return ParseError(position: position, messages: [])
        
    }
    
    /// Return an unexpected parse error.
    ///
    /// - parameters:
    ///   - position: The current position.
    ///   - message: The message string.
    /// - returns: An unexpected parse error.
    static func unexpectedParseError(position: SourcePosition, message: String) -> ParseError {
        
        return ParseError(position: position, messages: [.SystemUnexpected(message)])
        
    }
    
    /// Source position of the error.
    public var position: SourcePosition
    
    /// Sorted array of error messages.
    public var messages: [Message] {
        
        get { return _messages.sort() }
        
        set { _messages = newValue }
        
    }
    
    // Backing store for `messages`.
    private var _messages = [Message]()
    
    /// A textual representation of `self`.
    public var description: String {
        
        return String(position) + ":\n" + messagesDescription
        
    }
    
    private var messagesDescription: String {
        
        func msgsDesc(messageType: String, messages: [Message]) -> String {
            
            let msgs = messages.map({ $0.messageString }).clean()
            
            guard !msgs.isEmpty else { return "" }
            
            let msgType = messageType.isEmpty ? "" : messageType + " "
            
            if msgs.count == 1 {
                
                return msgType + msgs.first!
                
            }
            
            let commaSep = msgs.dropLast().joinWithSeparator(", ")
            
            let orStr =  NSLocalizedString("or", comment: "Error messages.")
            
            return msgType + commaSep + " " + orStr + " " + msgs.last!
            
        }
        
        guard !messages.isEmpty else {
            
            return NSLocalizedString("unknown parse error", comment: "Error messages.")
            
        }
        
        let (sysUnexpected, msgs1) = messages.part { $0 == .SystemUnexpected("") }
        let (unexpected, msgs2) = msgs1.part { $0 == .Unexpected("") }
        let (expected, generic) = msgs2.part { $0 == .Expected("") }
        
        // System unexpected messages.
        let sysUnexpectedDesc: String
        
        let unexpectedMsg = NSLocalizedString("unexpected", comment: "Error messages.")
        
        if !unexpected.isEmpty || sysUnexpected.isEmpty {
            
            sysUnexpectedDesc = ""
            
        } else {
            
            let firstMsg = sysUnexpected.first!.messageString
            
            if firstMsg.isEmpty {
                
                sysUnexpectedDesc = NSLocalizedString("unexpected end of input", comment: "Error messages.")
                
            } else {
            
                sysUnexpectedDesc = unexpectedMsg + " " + firstMsg
                
            }
            
        }
        
        // Unexpected messages.
        let unexpectedDesc = msgsDesc(unexpectedMsg, messages: unexpected)
        
        // Expected messages.
        let expectingMsg = NSLocalizedString("expecting", comment: "Error messages.")
        let expectedDesc = msgsDesc(expectingMsg, messages: expected)
        
        // Generic messages.
        let genericDesc = msgsDesc("", messages: generic)
        
        let descriptions = [sysUnexpectedDesc, unexpectedDesc, expectedDesc, genericDesc]
        return descriptions.clean().joinWithSeparator("\n")
        
    }
    
    /// Indicates if `self` is an unknown parse error.
    var isUnknown: Bool { return messages.isEmpty }
    
    /// Initializes from a source position and an array of messages.
    init(position: SourcePosition, messages: [Message]) {
        
        self.position = position
        self.messages = messages
        
    }
    
    /// Insert a message error in `messages`. All messages equal to the inserted messages are removed and the new message is inserted at the beginning of `messages`.
    ///
    /// - parameter message: The new message to insert in `messages`.
    mutating func insertMessage(message: Message) {
        
        messages = messages.replaceWith(message)
        
    }
    
    /// Insert the labels as `.Expected` message errors in `messages`.
    ///
    /// - parameter labels: The labels to insert.
    mutating func insertLabelsAsExpected(labels: [String]) {
        
        guard !labels.isEmpty else {
            
            insertMessage(.Expected(""))
            return
            
        }
        
        insertMessage(.Expected(labels[0]))
        
        for label in labels.suffixFrom(1) {
            
            messages.append(.Expected(label))
            
        }
        
    }
    
    /// Merge this `ParseError` with another `ParseError`.
    ///
    /// - parameter other: `ParseError` to merge with `self`.
    mutating func merge(other: ParseError) {
        
        let otherIsEmpty = other.messages.isEmpty
        
        // Prefer meaningful error.
        if messages.isEmpty && !otherIsEmpty {
            
            self = other
            
        } else if !otherIsEmpty {
            
            // Select the longest match
            if position == other.position {
                
                messages += other.messages
                
            } else if position < other.position {
                
                self = other
                
            }
            
        }
        
    }
    
}

extension SequenceType where Generator.Element == String {
    
    /// Return an array with duplicate and empty strings removed.
    private func clean() -> [Self.Generator.Element] {
        
        return self.removeDuplicates().filter { !$0.isEmpty }
        
    }
    
}