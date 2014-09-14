/*###################################################################################
#                                                                                   #
#    HTMLNode.swift                                                                 #
#                                                                                   #
#    Copyright © 2014 by Stefan Klieme                                              #
#                                                                                   #
#    Swift wrapper for HTML parser of libxml2                                       #
#                                                                                   #
#    Version 1.0 - 15. Sep 2014                                                     #
#                                                                                   #
#    usage:     add libxml2.dylib to frameworks (depends on autoload settings)      #
#               add $SDKROOT/usr/include/libxml2 to target -> Header Search Paths   #
#               add -lxml2 to target -> other linker flags                          #
#               add Bridging-Header.h to your project and rename it as              #
#                       [Modulename]-Bridging-Header.h                              #
#                    where [Modulename] is the module name in your project          #
#                                                                                   #
#####################################################################################
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy of   #
# this software and associated documentation files (the "Software"), to deal        #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies  #
# of the Software, and to permit persons to whom the Software is furnished to do    #
# so, subject to the following conditions:                                          #
# The above copyright notice and this permission notice shall be included in        #
# all copies or substantial portions of the Software.                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, #
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR      #
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.     #
#                                                                                   #
###################################################################################*/

import Foundation

private enum XMLElementType : UInt32
{
    case ELEMENT_NODE = 1
    case ATTRIBUTE_NODE = 2
    case TEXT_NODE = 3
    case CDATA_SECTION_NODE = 4
    case ENTITY_REF_NODE = 5
    case ENTITY_NODE = 6
    case PI_NODE = 7
    case COMMENT_NODE = 8
    case DOCUMENT_NODE = 9
    case DOCUMENT_TYPE_NODE = 10
    case DOCUMENT_FRAG_NODE = 11
    case NOTATION_NODE = 12
    case HTML_DOCUMENT_NODE = 13
    case DTD_NODE = 14
    case ELEMENT_DECL = 15
    case ATTRIBUTE_DECL = 16
    case ENTITY_DECL = 17
    case NAMESPACE_DECL = 18
    case XINCLUDE_START = 19
    case XINCLUDE_END = 20
    case DOCB_DOCUMENT_NODE = 21
}


extension NSString {
    
    func collapseCharactersinSet(characterSet: NSCharacterSet?,  usingSeparator separator: NSString) -> NSString
    {
        if self.length == 0 || characterSet == nil {
            return self
        }
        
        var array = self.componentsSeparatedByCharactersInSet(characterSet!)
        let result = array.reduce("") { "\($0)\(separator)\($1)" }
        return result
    }
    
    func collapseWhitespaceAndNewLine() -> NSString
    {
        return self.collapseCharactersinSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), usingSeparator:" ")
    }
    
    // ISO 639 identifier e.g. en_US or fr_CH
    func doubleValueForLocaleIdentifier(identifier: NSString) -> Double
        
    {
        return self.doubleValueForLocaleIdentifier(identifier, consideringPlusSign:false)
    }
    
    func doubleValueForLocaleIdentifier(identifier: NSString?, consideringPlusSign:Bool) -> Double
    {
        if self.length == 0 { return 0.0 }
        let numberFormatter = NSNumberFormatter()
        if (identifier != nil) {
            let locale = NSLocale(localeIdentifier:identifier!)
            numberFormatter.locale = locale
        }
        if consideringPlusSign && self.hasPrefix("+") {
            numberFormatter.positivePrefix = "+"
        }
        numberFormatter.numberStyle = .DecimalStyle
        let number = numberFormatter.numberFromString(self)
        
        return (number != nil) ? number!.doubleValue : 0.0
        
    }
    
    // date format e.g. @"yyyy-MM-dd 'at' HH:mm" --> 2001-01-02 at 13:00
    func dateValueWithFormat(dateFormat: NSString, timeZone:NSTimeZone) -> NSDate?
    {
        if self.length == 0 { return nil }
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = dateFormat
        dateFormatter.timeZone = timeZone
        return dateFormatter.dateFromString(self)
    }
    
}


class HTMLNode : SequenceType, Equatable, Printable {
    
    /*!
    * Constants
    */
    
    let DUMP_BUFFER_SIZE : UInt = 4000
    let kClassKey = "class"
    
    /*!
    * Private variables for the current node and its pointer
    */
    
    var pointer : xmlNodePtr?
    var node : xmlNode?
    
    // MARK: - init methods
    
    /*! Initializes and returns a newly allocated HTMLNode object with a specified xmlNode pointer.
    * \param xmlNode The xmlNode pointer for the created node object
    * \returns An initizlized HTMLNode object or nil if the object couldn't be created
    */
    
    init(pointer: xmlNodePtr = nil) {
        if pointer != nil {
            self.pointer = pointer
            self.node = pointer.memory
        }
    }
    
    // MARK: - navigating methods
    
    /*! The parent node
    * \returns The parent node or nil
    */

    var parent : HTMLNode? {
        if let parent = self.node?.parent {
            return HTMLNode(pointer:parent)
        }
        return nil
    }
    
    /*! The next sibling node
    * \returns The next sibling node or nil
    */
    
    var nextSibling : HTMLNode? {
        if let nextSibling = self.node?.next {
            return HTMLNode(pointer:nextSibling)
        }
        return nil
    }
    
    /*! The previous sibling node
    * \returns The previous sibling or nil
    */
    
    var previousSibling : HTMLNode? {
        if let previousSibling = self.node?.prev {
            return HTMLNode(pointer:previousSibling)
        }
        return nil
    }
    
    /*! The first child node
    * \returns The first child or nil
    */
    
    var firstChild : HTMLNode? {
        if let firstChild = self.node?.children {
            return HTMLNode(pointer:firstChild)
        }
        return nil
    }
    
    /*! The last child node
    * \returns The last child or nil
    */
    
    var lastChild : HTMLNode? {
        if let lastChild = self.node?.last {
            return HTMLNode(pointer:lastChild)
        }
        return nil
    }
    
    /*! The first level of children
    * \returns The children array or an empty array
    */
    
    // uncomment the '&& xmlNodeIsText(currentNode) == 0'to consider all the text nodes
    // see also the 'generate()' function
    
    var children : Array<HTMLNode> {
        var currentNode : xmlNodePtr
        var array = [HTMLNode]()
        if let node = self.node {
            for currentNode = node.children; currentNode != nil && xmlNodeIsText(currentNode) == 0; currentNode = currentNode.memory.next {
                let node = HTMLNode(pointer:currentNode)
                array.append(node)
            }
        }
        return array
    }

    /*! The child node at specified index
    * \param index The specified index
    * \returns The child node or nil if the index is invalid
    */
    
    func childAtIndex(index : Int) -> HTMLNode?
    {
        let childrenArray = self.children
        return (index < countElements(childrenArray)) ? childrenArray[index] : nil
    }

    /*! The number of children*/
    
    var childCount : UInt {
        if let uPointer = self.pointer {
            return xmlChildElementCount(uPointer)
        }
        return 0
    }
    
    // MARK: - attributes and values of current node (self)
    
    /*! The attribute value of a node matching a given name
    * \param attributeName A name of an attribute
    * \returns The attribute value or ab empty string if the attribute could not be found
    */
    
    func attributeForName(name : String) -> String
    {
        if let uPointer = self.pointer {
            let attributeValue = xmlGetProp(uPointer, xmlCharFrom(name))
            if (attributeValue != nil) {
                let result = stringFrom(attributeValue)
                free(attributeValue)
                return result
            }
        }
        return ""
    }
    
    /*! All attributes and values as dictionary
    * \returns a dictionary which could be empty if there are no attributes. Returns nil if the node is nil
    */
    
    var attributes : Dictionary<String, String>? {
        if let properties = self.node?.properties {
            
            var result = Dictionary<String, String>()
            for (var attr = properties; attr != nil ; attr = attr.memory.next) {
                let attrData = attr.memory
                let value = stringFrom(attrData.children.memory.content)
                let key = stringFrom(attrData.name)
                result[key] = value
            }
            return result
        }
        return nil
    }
    
    /*! The tag name
    * \returns The tag name or an empty string
    */
    
    var tagName : String {
        if let name = self.node?.name {
            return stringFrom(name)
        }
        return ""
    }
    
    /*! The value for the class attribute*/
    
    var className : String { // actually classValue
        return attributeForName(kClassKey)
    }
    
    /*! The value for the href attribute*/
    
    var hrefValue : String {
        return attributeForName("href")
    }
    
    /*! The value for the src attribute*/
    
    var srcValue : String {
        return attributeForName("src")
    }
    
    /*! The integer value*/
    
    var integerValue : Int {
        if let intValue = self.stringValue.toInt() {
            return intValue
        }
        return 0
    }
    
    /*! The double value*/
    
    var doubleValue : Double {
        return Double(self.integerValue)
    }
    
    /*! Returns the double value of the string value for a specified locale identifier
    * \param identifier A locale identifier. The locale identifier must conform to http://www.iso.org/iso/country_names_and_code_elements and http://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
    * \returns The double value of the string value depending on the parameter
    */
    
    func doubleValueForLocaleIdentifier(identifier : String) -> Double
    {
        return self.stringValue.doubleValueForLocaleIdentifier(identifier)
    }
    
    /*! Returns the double value of the string value for a specified locale identifier considering a plus sign prefix
    * \param identifier A locale identifier. The locale identifier must conform to http://www.iso.org/iso/country_names_and_code_elements and http://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
    * \param flag Considers the plus sign in the string if YES
    * \returns The double value of the string value depending on the parameters
    */
    
    func doubleValueForLocaleIdentifier(identifier : String, consideringPlusSign flag : Bool) -> Double
    {
        return self.stringValue.doubleValueForLocaleIdentifier(identifier, consideringPlusSign:flag)
    }
    
    /*! Returns the double value of the text content for a specified locale identifier
    * \param identifier A locale identifier. The locale identifier must conform to http://www.iso.org/iso/country_names_and_code_elements and http://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
    * \returns The double value of the text content depending on the parameter
    */
    
    func contentDoubleValueForLocaleIdentifier(identifier : String) -> Double
    {
        return self.textContent.doubleValueForLocaleIdentifier(identifier)
    }
    
    /*! Returns the double value of the text content for a specified locale identifier considering a plus sign prefix
    * \param identifier A locale identifier. The locale identifier must conform to http://www.iso.org/iso/country_names_and_code_elements and http://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
    * \param flag Considers the plus sign in the string if YES
    * \returns The double value of the text content depending on the parameters
    */
    
    func contentDoubleValueForLocaleIdentifier(identifier : String, consideringPlusSign flag: Bool) -> Double
    {
        return self.textContent.doubleValueForLocaleIdentifier(identifier, consideringPlusSign:flag)
    }
    
    /*! Returns the date value of the string value for a specified date format and time zone
    * \param dateFormat A date format string. The date format must conform to http://unicode.org/reports/tr35/tr35-10.html#Date_Format_Patterns
    * \param timeZone A time zone
    * \returns The date value of the string value depending on the parameters
    */
    
    // date format e.g. @"yyyy-MM-dd 'at' HH:mm" --> 2001-01-02 at 13:00
    func dateValueForFormat(dateFormat: String, timeZone: NSTimeZone) -> NSDate?
    {
        return self.stringValue.dateValueWithFormat(dateFormat, timeZone:timeZone)
    }
    
    /*! Returns the date value of the text content for a specified date format and time zone
    * \param dateFormat A date format string. The date format must conform to http://unicode.org/reports/tr35/tr35-10.html#Date_Format_Patterns
    * \param timeZone A time zone
    * \returns The date value of the text content depending on the parameters
    */
    
    func contentDateValueForFormat(dateFormat: String, timeZone: NSTimeZone) -> NSDate?
    {
        return self.textContent.dateValueWithFormat(dateFormat, timeZone:timeZone)
    }
    
    /*! Returns the date value of the string value for a specified date format
    * \param dateFormat A date format string. The date format must conform to http://unicode.org/reports/tr35/tr35-10.html#Date_Format_Patterns
    * \returns The date value of the string value depending on the parameter
    */
    
    func dateValueForFormat(dateFormat: String) -> NSDate?
    {
        return dateValueForFormat(dateFormat, timeZone:NSTimeZone.systemTimeZone())
    }
    
    
    /*! Returns the date value of the text content for a specified date format
    * \param dateFormat A date format string. The date format must conform to http://unicode.org/reports/tr35/tr35-10.html#Date_Format_Patterns
    * \returns The date value of the text content depending on the parameter
    */
    
    func contentDateValueForFormat(dateFormat: String) -> NSDate?
    {
        return self.contentDateValueForFormat(dateFormat, timeZone:NSTimeZone.systemTimeZone())
    }
    
    /*! The raw string
    * \returns The raw string value or an empty string
    */
    
    var rawStringValue : String {
        if let node = self.node {
            if node.children != nil {
                let string = node.children.memory.content
                if string != nil {
                    return stringFrom(string)
                }
            }
        }
        return ""
    }
    
    /*! The string value of a node trimmed by whitespace and newline characters
    * \returns The string value or an empty string
    */
    
    var stringValue : String {
        return self.rawStringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
    
    /*! The string value of a node trimmed by whitespace and newline characters and collapsing all multiple occurrences of whitespace and newline characters within the string into a single space
    * \returns The trimmed and collapsed string value or an empty string
    */
    
    var stringValueCollapsingWhitespace : String
        {
            return self.stringValue.collapseWhitespaceAndNewLine()
    }
    
    /*! The raw html text dump
    * \returns The raw html text dump or an empty string
    */
    
    var HTMLString : String {
        var result = ""
        
        if self.node != nil {
            var buffer : xmlBufferPtr = xmlBufferCreate()
            if buffer != nil {
                let err : Int32 = xmlNodeDump(buffer, nil, self.pointer!, 0, 0)
                if (err > -1) {
                    result = stringFrom(buffer.memory.content).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                }
                xmlBufferFree(buffer)
            }
        }
        
        return result
    }
    
    private func textContentOfChildren(nodePtr : xmlNodePtr, inout array : Array<String>, recursive : Bool)
    {
        var currentNode : xmlNodePtr?
        var content : String?
        
        for (currentNode = nodePtr; currentNode != nil; currentNode = currentNode!.memory.next) {
            
            content = textContent(currentNode!)
            if content != nil {
                if content!.isEmpty {
                    array.append(content!)
                } else {
                    var nsContent = content as NSString!
                    content = nsContent.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    if content!.isEmpty == false {
                        array.append(content!)
                    }
                }
            }
            
            if recursive {
                textContentOfChildren(currentNode!.memory.children, array: &array, recursive: recursive)
            }
        }
    }
    
    /*! The element type of the node*/
    
    var elementType : String {
        if let node = self.node {
            let rawType = xmlElementTypeToInt(node.type)
            if let nodeType = XMLElementType.fromRaw(rawType) {
                
                switch nodeType {
                    
                case .ELEMENT_NODE: return "Element"
                case .ATTRIBUTE_NODE: return "Attribute"
                case .TEXT_NODE: return "Text"
                case .CDATA_SECTION_NODE: return "CData Section"
                case .ENTITY_REF_NODE: return "Entity Ref"
                case .ENTITY_NODE: return "Entity"
                case .PI_NODE: return "Pi"
                case .COMMENT_NODE: return "Comment"
                case .DOCUMENT_NODE: return "Document"
                case .DOCUMENT_TYPE_NODE: return "Document Type"
                case .DOCUMENT_FRAG_NODE: return "Document Frag"
                case .NOTATION_NODE: return "Notation"
                case .HTML_DOCUMENT_NODE: return "HTML Document"
                case .DTD_NODE: return "DTD"
                case .ELEMENT_DECL: return "Element Declaration"
                case .ATTRIBUTE_DECL: return "Attribute Declaration"
                case .ENTITY_DECL: return "Entity Declaration"
                case .NAMESPACE_DECL: return "Namespace Declaration"
                case .XINCLUDE_START: return "Xinclude Start"
                case .XINCLUDE_END: return "Xinclude End"
                case .DOCB_DOCUMENT_NODE: return "DOCD Document"
                }
            }
        }
        return ""
    }
    
    /*! Is the node an attribute node
    * \returns Boolean value or  nil if the node doesn't exist
    */
    
    var isAttributeNode : Bool? {
        if let node = self.node {
            return xmlElementTypeToInt(node.type) == XMLElementType.ATTRIBUTE_NODE.toRaw()
        }
        return nil
    }
    
    /*! Is the node a document node
    * \returns Boolean value or  nil if the node doesn't exist
    */
    
    var isDocumentNode : Bool? {
        if let node = self.node {
            return xmlElementTypeToInt(node.type) == XMLElementType.HTML_DOCUMENT_NODE.toRaw()
        }
        return nil
    }
    
    /*! Is the node an element node
    * \returns Boolean value or  nil if the node doesn't exist
    */
    
    var isElementNode : Bool? {
        if let node = self.node {
            return xmlElementTypeToInt(node.type) == XMLElementType.ELEMENT_NODE.toRaw()
        }
        return nil
    }
    
    /*! Is the node a text node
    * \returns Boolean value or  nil if the node doesn't exist
    */
    
    var isTextNode : Bool? {
        if let node = self.node {
            return xmlElementTypeToInt(node.type) == XMLElementType.TEXT_NODE.toRaw()
        }
        return nil
    }
    
    /*! The array of all text content of children
    * \returns The text content array - each array item is trimmed by whitespace and newline characters - or an empty array
    */

    var textContentOfChildren : Array<String> {
        var array = Array<String>()
        if let node = self.node {
            textContentOfChildren(node.children, array:&array, recursive:false)
        }
        return array
    }
    
    
    // MARK: - attributes and values of current node and its descendants (descendant-or-self)
    
    private func textContent(nodePtr : xmlNodePtr?) -> String
    {
        if let pointer = nodePtr{
            let contents = xmlNodeGetContent(pointer)
            
            if contents != nil {
                let string = String.fromCString(UnsafePointer<CChar>(contents))
                free(contents)
                return string!
            }
        }
        return ""
    }
    
    /*! The raw text content of descendant-or-self
    * \returns The raw text content of the node and all its descendants or an empty string
    */
    
    var rawTextContent : String {
        return textContent(self.pointer)
    }
    
    /*! The text content of descendant-or-self trimmed by whitespace and newline characters
    * \returns The trimmed text content of the node and all its descendants or an empty string
    */

    var textContent : String {
        return textContent(self.pointer).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
    
    /*! The text content of descendant-or-self in an array, each item trimmed by whitespace and newline characters
    * \returns An array of all text content of the node and its descendants - each array item is trimmed by whitespace and newline characters - or an empty string
    */
    
    var textContentCollapsingWhitespace : String {
        return self.textContent.collapseWhitespaceAndNewLine()
    }
    
    /*! The text content of descendant-or-self in an array, each item trimmed by whitespace and newline characters
    * \returns An array of all text content of the node and its descendants - each array item is trimmed by whitespace and newline characters - or an empty string
    */
    
    var textContentOfDescendants : Array<String> {
        var array = Array<String>()
        if let node = self.node {
            textContentOfChildren(node.children, array:&array, recursive:true)
        }
        return array
    }

    /*! The raw html text dump of descendant-or-self
    * \returns The raw html text dump of the node and all its descendants or an empty string
    */
    
    var HTMLContent : String
        {
            var result : String = ""
            if let node = self.node {
                var xmlBuffer = xmlBufferCreateSize(DUMP_BUFFER_SIZE)
                var outputBuffer : xmlOutputBufferPtr = xmlOutputBufferCreateBuffer(xmlBuffer, nil)
                
                let document = node.doc
                let xmlCharContent = document.memory.encoding
                let contentAddress = unsafeBitCast(xmlCharContent, UnsafePointer<xmlChar>.self)
                let constChar = UnsafePointer<Int8>(contentAddress)
                
                htmlNodeDumpOutput(outputBuffer, document, self.pointer!, constChar)
                xmlOutputBufferFlush(outputBuffer)
                
                if xmlBuffer.memory.content != nil {
                    result = stringFrom(xmlBuffer.memory.content)
                }
                
                xmlOutputBufferClose(outputBuffer)
                xmlBufferFree(xmlBuffer)
            }
            
            return result
    }
    
    
    // MARK: -  query methods
    // Note: In the category HTMLNode+XPath all appropriate query methods begin with node instead of descendant
    
    
    private func childWithAttribute(attrName : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, recursive : Bool) -> HTMLNode?
    {
        var currentNodePtr : xmlNodePtr?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            for (var attr : xmlAttrPtr = currentNodePtr!.memory.properties; attr != nil ; attr = attr.memory.next) {
                if xmlStrEqual(attr.memory.name, attrName) == 1 {
                    return HTMLNode(pointer: currentNodePtr!)
                }
            }
            
            if recursive {
                if let subNode = childWithAttribute(attrName, nodePtr: currentNodePtr!.memory.children, recursive: recursive) {
                    return subNode
                }
            }
        }
        
        return nil
    }
    
    private func childWithAttributeValueMatches(attrName : UnsafePointer<xmlChar>, attrValue : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, recursive : Bool) -> HTMLNode?
    {
        var currentNodePtr : xmlNodePtr?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            
            for (var attr : xmlAttrPtr = currentNodePtr!.memory.properties; attr != nil ; attr = attr.memory.next) {
                if xmlStrEqual(attr.memory.name, attrName) == 1 {
                    let child = attr.memory.children
                    if child != nil && xmlStrEqual(child.memory.content, attrValue) == 1 {
                        return HTMLNode(pointer: currentNodePtr!)
                    }
                }
            }
            
            if (recursive) {
                if let subNode = childWithAttributeValueMatches(attrName, attrValue:attrValue, nodePtr: currentNodePtr!.memory.children, recursive: recursive) {
                    return subNode
                }
            }
        }
        
        return nil
    }
    
    private func childWithAttributeValueContains(attrName : UnsafePointer<xmlChar>, attrValue : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, recursive : Bool) -> HTMLNode?
    {
        var currentNodePtr : xmlNodePtr?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            
            for (var attr : xmlAttrPtr = currentNodePtr!.memory.properties; attr != nil ; attr = attr.memory.next) {
                if xmlStrEqual(attr.memory.name, attrName) == 1 {
                    let child = attr.memory.children
                    if child != nil && xmlStrstr(child.memory.content, attrValue) != nil {
                        return HTMLNode(pointer: currentNodePtr!)
                    }
                }
            }
            
            if (recursive) {
                if let subNode = childWithAttributeValueContains(attrName, attrValue:attrValue, nodePtr: currentNodePtr!.memory.children, recursive: recursive) {
                    return subNode
                }
            }
        }
        return nil
    }
    
    private func childrenWithAttribute(attrName : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, inout array : Array<HTMLNode>, recursive : Bool)
    {
        if attrName == nil { return }
        
        var currentNodePtr : xmlNodePtr?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            
            for (var attr : xmlAttrPtr = currentNodePtr!.memory.properties; attr != nil ; attr = attr.memory.next) {
                if xmlStrEqual(attr.memory.name, attrName) == 1 {
                    let matchingNode = HTMLNode(pointer: currentNodePtr!)
                    array.append(matchingNode)
                    break
                }
            }
            
            if (recursive)  {
                childrenWithAttribute(attrName, nodePtr: currentNodePtr!.memory.children, array:&array, recursive:recursive)
            }
        }
    }
    
    private func childrenWithAttributeValueMatches(attrName : UnsafePointer<xmlChar>, attrValue : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, inout array : Array<HTMLNode>, recursive : Bool)
        
    {
        if attrName == nil { return }
        
        var currentNodePtr : xmlNodePtr?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            
            for (var attr : xmlAttrPtr = currentNodePtr!.memory.properties; attr != nil ; attr = attr.memory.next) {
                if xmlStrEqual(attr.memory.name, attrName) == 1 {
                    let child = attr.memory.children
                    if child != nil && xmlStrEqual(child.memory.content, attrValue) == 1 {
                        let matchingNode = HTMLNode(pointer: currentNodePtr!)
                        array.append(matchingNode)
                        break
                    }
                }
            }
            
            if (recursive)  {
                childrenWithAttributeValueMatches(attrName, attrValue:attrValue, nodePtr: currentNodePtr!.memory.children, array:&array, recursive:recursive)
            }
        }
    }
    
    private func childrenWithAttributeValueContains(attrName : UnsafePointer<xmlChar>, attrValue : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, inout array : Array<HTMLNode>, recursive : Bool)
        
    {
        if attrName == nil { return }
        
        var currentNodePtr : xmlNodePtr?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            
            for (var attr : xmlAttrPtr = currentNodePtr!.memory.properties; attr != nil ; attr = attr.memory.next) {
                if xmlStrEqual(attr.memory.name, attrName) == 1 {
                    let child = attr.memory.children
                    if child != nil && xmlStrstr(child.memory.content, attrValue) != nil {
                        let matchingNode = HTMLNode(pointer: currentNodePtr!)
                        array.append(matchingNode)
                        break
                    }
                }
            }
            
            if (recursive)  {
                childrenWithAttributeValueContains(attrName, attrValue:attrValue, nodePtr: currentNodePtr!.memory.children, array:&array, recursive:recursive)
            }
            
        }
    }
    
    /*! Returns the first descendant node with the specifed attribute name and value matching exactly
    * \param attributeName The name of the attribute
    * \param attributeValue The value of the attribute
    * \returns The first found descendant node or nil if no node matches the parameters
    */
    
    func descendantWithAttribute(attributeName : String, valueMatches attributeValue: String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueMatches(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.children, recursive: true)
        }
        return nil
    }
    
    /*! Returns the first child node with the specifed attribute name and value matching exactly
    * \param attributeName The name of the attribute
    * \param attributeValue The value of the attribute
    * \returns The first found child node or nil if no node matches the parameters
    */
    
    func childWithAttribute(attributeName : String, valueMatches attributeValue: String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueMatches(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.children, recursive: false)
        }
        return nil
        
    }
    
    /*! Returns the first sibling node with the specifed attribute name and value matching exactly
    * \param attributeName The name of the attribute
    * \param attributeValue The value of the attribute
    * \returns The first found sibling node or nil if no node matches the parameters
    */
    
    func siblingWithAttribute(attributeName : String, valueMatches attributeValue: String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueMatches(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.next, recursive: false)
        }
        return nil
    }
    
    /*! Returns the first descendant node with the specifed attribute name and the value contains the specified attribute value
    * \param attributeName The name of the attribute
    * \param attributeValue The partial string of the attribute value
    * \returns The first found descendant node or nil if no node matches the parameters
    */
    
    func descendantWithAttribute(attributeName : String, valueContains attributeValue: String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueContains(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.children, recursive: true)
        }
        return nil
    }
    
    /*! Returns the first child node with the specifed attribute name and the value contains the specified attribute value
    * \param attributeName The name of the attribute
    * \param attributeValue The partial string of the attribute value
    * \returns The first found child node or nil if no node matches the parameters
    */
    
    func childWithAttribute(attributeName : String, valueContains attributeValue: String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueContains(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.children, recursive: false)
        }
        return nil
    }
    
    /*! Returns the first sibling node with the specifed attribute name and the value contains the specified attribute value
    * \param attributeName The name of the attribute
    * \param attributeValue The partial string of the attribute value
    * \returns The first found sibling node or nil if no node matches the parameters
    */
    
    func siblingWithAttribute(attributeName : String, valueContains attributeValue: String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueContains(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.next, recursive: false)
        }
        return nil
        
    }
    
    /*! Returns all descendant nodes with the specifed attribute name and value matching exactly
    * \param attributeName The name of the attribute
    * \param attributeValue The value of the attribute
    * \returns The array of all found descendant nodes or an empty array
    */
    
    func descendantsWithAttribute(attributeName : String, valueMatches attributeValue: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttributeValueMatches(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.children, array:&array, recursive: true)
        }
        return array
    }
    
    /*! Returns all child nodes with the specifed attribute name and value matching exactly
    * \param attributeName The name of the attribute
    * \param attributeValue The value of the attribute
    * \returns The array of all found child nodes or an empty array
    */
    
    func childrenWithAttribute(attributeName : String, valueMatches attributeValue: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttributeValueMatches(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.children, array:&array, recursive: false)
        }
        return array
    }
    
    /*! Returns all sibling nodes with the specifed attribute name and value matching exactly
    * \param attributeName The name of the attribute
    * \param attributeValue The value of the attribute
    * \returns The array of all found sibling nodes or an empty array
    */
    
    func siblingsWithAttribute(attributeName : String, valueMatches attributeValue: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttributeValueMatches(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.next, array:&array, recursive: false)
        }
        return array
    }
    
    /*! Returns all descendant nodes with the specifed attribute name and the value contains the specified attribute value
    * \param attributeName The name of the attribute
    * \param attributeValue The partial string of the attribute value
    * \returns The array of all found descendant nodes or an empty array
    */
    
    func descendantsWithAttribute(attributeName : String, valueContains attributeValue: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttributeValueContains(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.children, array:&array, recursive: true)
        }
        return array
    }
    
    /*! Returns all child nodes with the specifed attribute name and the value contains the specified attribute value
    * \param attributeName The name of the attribute
    * \param attributeValue The partial string of the attribute value
    * \returns The array of all found child nodes or an empty array
    */
    
    func childrenWithAttribute(attributeName : String, valueContains attributeValue: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttributeValueContains(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.children, array:&array, recursive: false)
        }
        return array
    }
    
    /*! Returns all sibling nodes with the specifed attribute name and the value contains the specified attribute value
    * \param attributeName The name of the attribute
    * \param attributeValue The partial string of the attribute value
    * \returns The array of all found sibling nodes or an empty array
    */
    
    func siblingsWithAttribute(attributeName : String, valueContains attributeValue: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttributeValueContains(xmlCharFrom(attributeName), attrValue:xmlCharFrom(attributeValue), nodePtr: node.next, array:&array, recursive: false)
        }
        return array
    }
    
    /*! Returns the first descendant node with the specifed attribute name
    * \param attributeName The name of the attribute
    * \returns The first found descendant node or nil
    */
    
    func descendantWithAttribute(attributeName : String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttribute(xmlCharFrom(attributeName), nodePtr: node.children, recursive: true)
        }
        return nil
    }
    
    /*! Returns the first child node with the specifed attribute name
    * \param attributeName The name of the attribute
    * \returns The first found child node or nil
    */
    
    func childWithAttribute(attributeName : String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttribute(xmlCharFrom(attributeName), nodePtr: node.children, recursive: false)
        }
        return nil
    }
    
    /*! Returns the first sibling node with the specifed attribute name
    * \param attributeName The name of the attribute
    * \returns The first found sibling node or nil
    */
    
    func siblingWithAttribute(attributeName : String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttribute(xmlCharFrom(attributeName), nodePtr: node.next, recursive: false)
        }
        return nil
    }
    
    /*! Returns all descendant nodes with the specifed attribute name
    * \param attributeName The name of the attribute
    * \returns The array of all found descendant nodes or an empty array
    */
    
    func descendantsWithAttribute(attributeName : String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttribute(xmlCharFrom(attributeName), nodePtr: node.children, array:&array, recursive: true)
        }
        return array
    }
    
    /*! Returns all child nodes with the specifed attribute name
    * \param attributeName The name of the attribute
    * \returns The array of all found child nodes or an empty array
    */
    
    func childrenWithAttribute(attributeName : String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttribute(xmlCharFrom(attributeName), nodePtr: node.children, array:&array, recursive: false)
        }
        return array
    }
    
    /*! Returns all sibling nodes with the specifed attribute name
    * \param attributeName The name of the attribute
    * \returns The array of all found sibling nodes or an empty array
    */
    
    func siblingsWithAttribute(attributeName : String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenWithAttribute(xmlCharFrom(attributeName), nodePtr: node.next, array:&array, recursive: false)
        }
        return array
    }
    
    /*! Returns the first descendant node with the specifed class name
    * \param classValue The name of the class
    * \returns The first found descendant node or nil
    */
    
    func descendantWithClass(classValue : String) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueMatches(xmlCharFrom("class"), attrValue:xmlCharFrom(classValue), nodePtr: node.children, recursive: true)
        }
        return nil
    }
    
    /*! Returns the first child node with the specifed class name
    * \param classValue The name of the class
    * \returns The first found child node or nil
    */
    
    func childWithClass(classValue : NSString) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueMatches(xmlCharFrom("class"), attrValue:xmlCharFrom(classValue), nodePtr: node.children, recursive: false)
        }
        return nil
    }
    
    /*! Returns the first sibling node with the specifed class name
    * \param classValue The name of the class
    * \returns The first found sibling node or nil
    */
    
    func siblingWithClass(classValue : NSString) -> HTMLNode?
    {
        if let node = self.node {
            return childWithAttributeValueMatches(xmlCharFrom("class"), attrValue:xmlCharFrom(classValue), nodePtr: node.next, recursive: false)
        }
        return nil
    }
    
    /*! Returns all descendant nodes with the specifed class name
    * \param classValue The name of the class
    * \returns The array of all found descendant nodes or an empty array
    */
    
    func descendantsWithClass(classValue : NSString) -> Array<HTMLNode>
    {
        return self.descendantsWithAttribute(kClassKey, valueMatches:classValue)
    }
    
    /*! Returns all child nodes with the specifed class name
    * \param classValue The name of the class
    * \returns The array of all found child nodes or an empty array
    */
    
    func childrenWithClass(classValue : NSString) -> Array<HTMLNode>
    {
        return self.childrenWithAttribute(kClassKey, valueMatches:classValue)
    }
    
    /*! Returns all sibling nodes with the specifed class name
    * \param classValue The name of the class
    * \returns The array of all found sibling nodes or an empty array
    */
    
    func siblingsWithClass(classValue : NSString) -> Array<HTMLNode>
    {
        return self.siblingsWithAttribute(kClassKey, valueMatches:classValue)
    }
    
    
    private func childOfTagValueMatches(tagName : UnsafePointer<xmlChar>, value : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, recursive : Bool) -> HTMLNode?
    {
        
        var currentNodePtr, childNodePtr : xmlNodePtr?
        var childName : UnsafeMutablePointer<xmlChar>?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            if xmlStrEqual(currentNodePtr!.memory.name, value) == 1 {
                
                childNodePtr = currentNodePtr!.memory.children
                childName = (childNodePtr != nil) ? childNodePtr!.memory.content : nil
                if childName != nil && xmlStrEqual(childName!, value) == 1 {
                    return HTMLNode(pointer: currentNodePtr!)
                }
            }
            if recursive {
                if let subNode = childOfTagValueMatches(tagName, value:value, nodePtr: currentNodePtr!.memory.children, recursive:recursive) {
                    return subNode
                    
                }
            }
        }
        return nil
    }
    
    private func childOfTagValueContains(tagName : UnsafePointer<xmlChar>, value : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, recursive : Bool) -> HTMLNode?
    {
        var currentNodePtr, childNodePtr : xmlNodePtr?
        var childName : UnsafeMutablePointer<xmlChar>?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            if xmlStrEqual(currentNodePtr!.memory.name, value) == 1 {
                
                childNodePtr = currentNodePtr!.memory.children
                childName = (childNodePtr != nil) ? childNodePtr!.memory.content : nil
                if childName != nil  && xmlStrstr(childName!, value) != nil {
                    return HTMLNode(pointer: currentNodePtr!)
                }
            }
            if recursive {
                if let subNode = childOfTagValueContains(tagName, value:value, nodePtr: currentNodePtr!.memory.children, recursive:recursive) {
                    return subNode
                    
                }
            }
        }
        return nil
    }
    
    /*! Returns the first descendant node with the specifed tag name and string value matching exactly
    * \param tagName The name of the tag
    * \param value The string value of the tag
    * \returns The first found descendant node or nil if no node matches the parameters
    */
    
    func descendantOfTag(tagName : String, valueMatches: String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTagValueMatches(xmlCharFrom(tagName), value:xmlCharFrom(valueMatches),  nodePtr:node.children, recursive:true)
        }
        return nil
    }
    
    /*! Returns the first child node with the specifed tag name and string value matching exactly
    * \param tagName The name of the tag
    * \param value The string value of the tag
    * \returns The first found child node or nil if no node matches the parameters
    */
    
    func childOfTag(tagName : String, valueMatches: String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTagValueMatches(xmlCharFrom(tagName), value:xmlCharFrom(valueMatches), nodePtr:node.children, recursive:false)
        }
        return nil
    }
    
    /*! Returns the first sibling node with the specifed tag name and string value matching exactly
    * \param tagName The name of the tag
    * \param value The string value of the tag
    * \returns The first found sibling node or nil if no node matches the parameters
    */
    
    func siblingOfTag(tagName : String, valueMatches: String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTagValueMatches(xmlCharFrom(tagName), value:xmlCharFrom(valueMatches), nodePtr:node.next, recursive:false)
        }
        return nil
    }
    
    /*! Returns the first descendant node with the specifed attribute name and the string value contains the specified value
    * \param tagName The name of the attribute
    * \param value The partial string of the attribute value
    * \returns The first found descendant node or nil if no node matches the parameters
    */
    
    func descendantOfTag(tagName : String, valueContains: String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTagValueContains(xmlCharFrom(tagName), value:xmlCharFrom(valueContains), nodePtr:node.children, recursive:true)
        }
        return nil
    }
    
    /*! Returns the child node with the specifed attribute name and the string value contains the specified value
    * \param tagName The name of the attribute
    * \param value The partial string of the attribute value
    * \returns The first found child node or nil if no node matches the parameters
    */
    
    func childOfTag(tagName : String, valueContains: String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTagValueContains(xmlCharFrom(tagName), value:xmlCharFrom(valueContains), nodePtr:node.children, recursive:false)
        }
        return nil
    }
    
    /*! Returns the sibling node with the specifed attribute name and the string value contains the specified value
    * \param tagName The name of the attribute
    * \param value The partial string of the attribute value
    * \returns The first found sibling node or nil if no node matches the parameters
    */
    
    func siblingOfTag(tagName : String, valueContains: String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTagValueContains(xmlCharFrom(tagName), value:xmlCharFrom(valueContains), nodePtr:node.next, recursive:false)
        }
        return nil
    }
    

    private func childrenOfTagValueMatches(tagName : UnsafePointer<xmlChar>, value : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, inout array : Array<HTMLNode>, recursive : Bool)
    {
        if tagName == nil { return }
        
        var currentNodePtr, childNodePtr : xmlNodePtr?
        var childName : UnsafeMutablePointer<xmlChar>?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            if xmlStrEqual(currentNodePtr!.memory.name, value) == 1 {
                
                childNodePtr = currentNodePtr!.memory.children
                childName = (childNodePtr != nil) ? childNodePtr!.memory.content : nil
                if childName != nil && xmlStrEqual(childName!, value) == 1 {
                    let matchingNode = HTMLNode(pointer: currentNodePtr!)
                    array.append(matchingNode)
                }
            }
            if (recursive) {
                childrenOfTagValueMatches(tagName, value:value, nodePtr:currentNodePtr!.memory.children, array:&array, recursive:recursive)
            }
        }
    }
    
    private func childrenOfTagValueContains(tagName : UnsafePointer<xmlChar>, value : UnsafePointer<xmlChar>, nodePtr: xmlNodePtr, inout array : Array<HTMLNode>, recursive : Bool)
    {
        if tagName == nil { return }
        
        var currentNodePtr, childNodePtr : xmlNodePtr?
        var childName : UnsafeMutablePointer<xmlChar>?
        
        for (currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr!.memory.next) {
            if xmlStrEqual(currentNodePtr!.memory.name, value) == 1 {
                childNodePtr = currentNodePtr!.memory.children
                childName = (childNodePtr != nil) ? childNodePtr!.memory.content : nil
                if childName != nil && xmlStrstr(childName!, value) != nil {
                    let matchingNode = HTMLNode(pointer: currentNodePtr!)
                    array.append(matchingNode)
                }
            }
            if (recursive) {
                childrenOfTagValueContains(tagName, value:value, nodePtr:currentNodePtr!.memory.children, array:&array, recursive:recursive)
            }
        }
    }
    
    /*! Returns all descendant nodes with the specifed tag name and string value matching exactly
    * \param tagName The name of the tag
    * \param value The string value of the tag
    * \returns The array of all found descendant nodes or an empty array
    */
    
    func descendantsOfTag(tagName : String, valueMatches: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTagValueMatches(xmlCharFrom(tagName), value:xmlCharFrom(valueMatches), nodePtr:node.children, array:&array, recursive:true)
        }
        return array
    }
    
    /*! Returns all child nodes with the specifed tag name and string value matching exactly
    * \param tagName The name of the tag
    * \param value The string value of the tag
    * \returns The array of all found child nodes or an empty array
    */
    
    func childrenOfTag(tagName : String, valueMatches: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTagValueMatches(xmlCharFrom(tagName), value:xmlCharFrom(valueMatches), nodePtr:node.children, array:&array, recursive:false)
        }
        return array
    }
    
    /*! Returns all sibling nodes with the specifed tag name and string value matching exactly
    * \param tagName The name of the tag
    * \param value The string value of the tag
    * \returns The array of all found sibling nodes or an empty array
    */
    
    func siblingsOfTag(tagName : String, valueMatches: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTagValueMatches(xmlCharFrom(tagName), value:xmlCharFrom(valueMatches), nodePtr:node.next, array:&array, recursive:false)
        }
        return array
    }
    
    /*! Returns all descendant nodes with the specifed attribute name and the string value contains the specified value
    * \param tagName The name of the attribute
    * \param value The partial string of the attribute value
    * \returns The array of all found descendant nodes or an empty array
    */
    
    func descendantsOfTag(tagName : String, valueContains: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTagValueContains(xmlCharFrom(tagName), value:xmlCharFrom(valueContains),  nodePtr:node.children, array:&array, recursive:true)
        }
        return array
    }
    
    /*! Returns all child nodes with the specifed attribute name and the string value contains the specified value
    * \param tagName The name of the attribute
    * \param value The partial string of the attribute value
    * \returns The array of all found child nodes or an empty array
    */
    
    func childrenOfTag(tagName : String, valueContains: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTagValueContains(xmlCharFrom(tagName), value:xmlCharFrom(valueContains),  nodePtr:node.children, array:&array, recursive:false)
        }
        return array
    }
    
    /*! Returns all sibling nodes with the specifed attribute name and the string value contains the specified value
    * \param tagName The name of the attribute
    * \param value The partial string of the attribute value
    * \returns The array of all found sibling nodes or an empty array
    */
    
    func siblingsOfTag(tagName : String, valueContains: String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTagValueContains(xmlCharFrom(tagName), value:xmlCharFrom(valueContains),  nodePtr:node.next, array:&array, recursive:false)
        }
        return array
    }
    
    
    
    private func childOfTag(tagName : UnsafePointer<xmlChar>, nodePtr : xmlNodePtr, recursive: Bool)  -> HTMLNode?
    {
        var currentNodePtr : xmlNodePtr
        
        for currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr.memory.next {
            let currentNode = currentNodePtr.memory
            if currentNode.name != nil &&  xmlStrEqual(currentNode.name, tagName) == 1 {
                return HTMLNode(pointer:currentNodePtr)
            }
            if recursive {
                var subNode = childOfTag(tagName, nodePtr:currentNodePtr.memory.children, recursive:recursive)
                if subNode != nil {
                    return subNode
                }
                
            }
        }
        
        return nil
    }
    
    /*! Returns the first descendant node with the specifed tag name
    * \param tagName The name of the tag
    * \returns The first found descendant node or nil
    */
    
    func descendantOfTag(tagName : String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTag(xmlCharFrom(tagName), nodePtr:node.children, recursive:true)
        }
        return nil
    }
    
    /*! Returns the first child node with the specifed tag name
    * \param tagName The name of the tag
    * \returns The first found child node or nil
    */
    
    func childOfTag(tagName : String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTag(xmlCharFrom(tagName), nodePtr:node.children, recursive:false)
        }
        return nil
    }
    
    /*! Returns the first sibling node with the specifed tag name
    * \param tagName The name of the tag
    * \returns The first found sibling node or nil
    */
    
    func siblingOfTag(tagName : String) -> HTMLNode?
    {
        if let node = self.node {
            return childOfTag(xmlCharFrom(tagName), nodePtr:node.next, recursive:false)
        }
        return nil
    }
    
    
    private func childrenOfTag(tagName : UnsafePointer<xmlChar>,  nodePtr : xmlNodePtr, inout array : Array<HTMLNode>, recursive: Bool)
    {
        if tagName == nil { return }
        
        var currentNodePtr : xmlNodePtr
        
        for currentNodePtr = nodePtr; currentNodePtr != nil; currentNodePtr = currentNodePtr.memory.next {
            let currentNode = currentNodePtr.memory
            if currentNode.name != nil &&  xmlStrEqual(currentNode.name, tagName) == 1 {
                let matchingNode = HTMLNode(pointer: currentNodePtr)
                array.append(matchingNode)
            }
            
            if recursive {
                childrenOfTag(tagName, nodePtr:currentNodePtr.memory.children, array:&array, recursive:recursive)
            }
        }
    }
    
    /*! Returns all descendant nodes with the specifed tag name
    * \param tagName The name of the tag
    * \returns The array of all found descendant nodes or an empty array
    */
    
    func descendantsOfTag(tagName : String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTag(xmlCharFrom(tagName), nodePtr:node.children, array:&array, recursive:true)
        }
        return array
    }
    
    /*! Returns all child nodes with the specifed tag name
    * \param tagName The name of the tag
    * \returns The array of all found child nodes or an empty array
    */
    
    func childrenOfTag(tagName : String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTag(xmlCharFrom(tagName), nodePtr:node.children, array:&array, recursive:false)
        }
        return array
    }
    
    /*! Returns all sibling nodes with the specifed tag name
    * \param tagName The name of the tag
    * \returns The array of all found sibling nodes or an empty array
    */
    
    func siiblingsOfTag(tagName : String) -> Array<HTMLNode>
    {
        var array = Array<HTMLNode>()
        if let node = self.node {
            childrenOfTag(xmlCharFrom(tagName),  nodePtr:node.next, array:&array, recursive:false)
        }
        return array
    }
    
    // MARK: mark - description
    
    // includes type, name , number of children, attributes and the raw content
    var description : String {
        if self.node == nil { return "" }
        var attrs : AnyObject!
        if attributes != nil {
            attrs = attributes!
        } else {
            attrs = "nil"
        }
        return "type: \(elementType) - tag name: \(tagName) - number of children: \(childCount)\nattributes: \(attrs)\nHTML: \(HTMLString)"
    }
    
    // creates a String from a xmlChar
    
    func stringFrom(char: UnsafePointer<xmlChar>) -> String {
        if let string = String.fromCString(UnsafePointer<CChar>(char)) {
            return string
        }
        return ""
    }
    
    // creates a xmlChar from a String
    
    func xmlCharFrom(string: String) -> UnsafePointer<xmlChar> {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding)!
        return UnsafePointer<xmlChar>(data.bytes)
    }
    
    // sequence generator to be able to write "for item in HTMLNode" as a shortcut for "for item in HTMLNode.children"
    
    func generate() -> GeneratorOf<HTMLNode> {
        var node = self.pointer?.memory.children
        return GeneratorOf<HTMLNode> {
            if xmlNodeIsText(node!) == 1 {
                node = node!.memory.next
                if node!.hashValue == 0 { return .None }
            }
            let nextNode = HTMLNode(pointer:node!)
            node = node!.memory.next
            if node!.hashValue == 0 {
                return .None
            } else {
                return nextNode
            }
        }
        
    }

    // alternative sequence generator to consider all text nodes
    // see also the 'children' property


//    func generate() -> GeneratorOf<HTMLNode> {
//        var node = self.pointer?.memory.children
//        return GeneratorOf<HTMLNode> {
//            if node!.hashValue != 0 {
//                let nextNode = HTMLNode(pointer:node!)
//                node = node!.memory.next
//                return nextNode
//            } else {
//                return .None
//            }
//        }
//        
//    }
    
}

// MARK: -  Equation protocol

func == (lhs: HTMLNode, rhs: HTMLNode) -> Bool {
    
    if lhs.pointer != nil && rhs.pointer != nil {
        return xmlXPathCmpNodes(lhs.pointer!, rhs.pointer!) == 0
    }
    return false
}



