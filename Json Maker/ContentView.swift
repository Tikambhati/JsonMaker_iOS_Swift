//
//  ContentView.swift
//  Json Maker
//
//  Created by Tikam Bhati   on 25/03/26.
//

//
//  ContentView.swift
//  Json Maker
//
//  Created by Tikam Bhati   on 25/03/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    
    @State private var jsonInput: String = ""
    @State private var output: String = ""
    @State private var errorMessage: String = ""
    @State private var modelName: String = ""
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            // 🔹 TOP BAR
            HStack {
                Text("Model Name:")
                
                TextField("Enter model name", text: $modelName)
                    .frame(width: 200)
                    .onChange(of: modelName) { _ in
                        validateJSON() // 🔥 live update
                    }
                
                Button("Open .json File") {
                    openFile()
                }
                
                Spacer()
                
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            .padding()
            
            Divider()
            
            // 🔹 SPLIT VIEW
            HStack(spacing: 0) {
                
                TextEditor(text: $jsonInput)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: jsonInput) { _ in
                        validateJSON()
                    }
                
                Divider()
                
                TextEditor(text: $output)
                    .font(.system(.body, design: .monospaced))
                    .background(Color.black.opacity(0.05))
            }
            
            Divider()
            
            // 🔹 BOTTOM
            HStack {
                Spacer()
                Button("Save") {
                    saveFile()
                }
            }
            .padding()
        }
        .frame(minWidth: 1000, minHeight: 650)
    }
    
    // 🔥 VALIDATION
    func validateJSON() {
        
        guard let data = jsonInput.data(using: .utf8) else {
            errorMessage = "Invalid encoding"
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            
            let cleanInput = modelName.trimmingCharacters(in: .whitespaces)
            errorMessage = cleanInput.isEmpty
                ? "⚠️ Using default: AutoModel"
                : "✅ Valid JSON"
            
            generateModel(json: json)
            
        } catch {
            errorMessage = "❌ Invalid JSON"
            output = ""
        }
    }
    
    // 🔥 MAIN GENERATOR
    func generateModel(json: Any) {
        
        guard let dict = json as? [String: Any] else { return }
        
        let cleanInput = modelName.trimmingCharacters(in: .whitespaces)
        let finalName = cleanInput.isEmpty ? "AutoModel" : cleanInput.capitalized
        
        let rootName = "\(finalName)Root"
        let resultName = "\(finalName)Result"
        
        var result = ""
        
        result += generateRoot(rootName: rootName, resultName: resultName)
        
        if let resultDict = dict["Result"] as? [String: Any] {
            result += parseStruct(name: resultName, dict: resultDict)
        }
        
        output = result
    }
    
    // 🔹 ROOT
    func generateRoot(rootName: String, resultName: String) -> String {
        
        return """
struct \(rootName) {

    var result : \(resultName)!
    var statusCode : Int!
    var statusDescription : String!
    var statusMessage : String!
    var version : String!

    init(fromJson json: JSON!){
        if json.isEmpty{
            return
        }

        let resultJson = json["Result"]
        if !resultJson.isEmpty{
            result = \(resultName)(fromJson: resultJson)
        }
        statusCode = json["StatusCode"].intValue
        statusDescription = json["StatusDescription"].stringValue
        statusMessage = json["StatusMessage"].stringValue
        version = json["Version"].stringValue
    }

}

"""
    }
    
    // 🔁 STRUCT GENERATOR
    func parseStruct(name: String, dict: [String: Any]) -> String {
        
        var properties = ""
        var initCode = ""
        var toDict = ""
        var nested = ""
        
        for (key, value) in dict {
            
            let safeKey = key.replacingOccurrences(of: " ", with: "")
            
            if let subDict = value as? [String: Any] {
                
                let child = "\(safeKey)Result"
                
                properties += "    var \(safeKey) : \(child)!\n"
                
                initCode += "        let \(safeKey)Json = json[\"\(key)\"]\n"
                initCode += "        if !\(safeKey)Json.isEmpty{\n"
                initCode += "            \(safeKey) = \(child)(fromJson: \(safeKey)Json)\n"
                initCode += "        }\n\n"
                
                toDict += "        if \(safeKey) != nil{\n"
                toDict += "            dictionary[\"\(key)\"] = \(safeKey).toDictionary()\n"
                toDict += "        }\n\n"
                
                nested += parseStruct(name: child, dict: subDict)
            }
            
            else if let array = value as? [[String: Any]] {
                
                let child = "\(safeKey)Item"
                
                properties += "    var \(safeKey) : [\(child)]!\n"
                
                initCode += "        \(safeKey) = [\(child)]()\n"
                initCode += "        let \(safeKey)Array = json[\"\(key)\"].arrayValue\n"
                initCode += "        for dataJson in \(safeKey)Array{\n"
                initCode += "            let value = \(child)(fromJson: dataJson)\n"
                initCode += "            \(safeKey).append(value)\n"
                initCode += "        }\n\n"
                
                toDict += "        if \(safeKey) != nil{\n"
                toDict += "            var dictionaryElements = [[String:Any]]()\n"
                toDict += "            for dataElement in \(safeKey) {\n"
                toDict += "                dictionaryElements.append(dataElement.toDictionary())\n"
                toDict += "            }\n"
                toDict += "            dictionary[\"\(key)\"] = dictionaryElements\n"
                toDict += "        }\n\n"
                
                if let first = array.first {
                    nested += parseStruct(name: child, dict: first)
                }
            }
            
            else {
                
                let type = getType(value)
                
                properties += "    var \(safeKey) : \(type)!\n"
                
                initCode += "        \(safeKey) = json[\"\(key)\"].\(jsonType(value))\n\n"
                
                toDict += "        if \(safeKey) != nil{\n"
                toDict += "            dictionary[\"\(key)\"] = \(safeKey)\n"
                toDict += "        }\n\n"
            }
        }
        
        return """
struct \(name) {

\(properties)

    init(fromJson json: JSON!){
        if json.isEmpty{
            return
        }

\(initCode)    }

    func toDictionary() -> [String:Any]
    {
        var dictionary = [String:Any]()

\(toDict)        return dictionary
    }

}

\(nested)
"""
    }
    
    // 🔍 TYPE FIX (BOOL ISSUE)
    func getType(_ value: Any) -> String {

        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return "Bool"
            } else {
                return "Int"
            }
        }

        switch value {
        case is Double: return "Double"
        case is String: return "String"
        default: return "String"
        }
    }
    
    func jsonType(_ value: Any) -> String {

        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return "boolValue"
            } else {
                return "intValue"
            }
        }

        switch value {
        case is Double: return "doubleValue"
        case is String: return "stringValue"
        default: return "stringValue"
        }
    }
    
    // 📂 OPEN FILE
    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        
        if panel.runModal() == .OK {
            if let url = panel.url,
               let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                jsonInput = text
            }
        }
    }
    
    // 💾 SAVE FILE
    func saveFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.swiftSource]
        panel.nameFieldStringValue = "Model.swift"

        if panel.runModal() == .OK {
            if let url = panel.url {
                try? output.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
