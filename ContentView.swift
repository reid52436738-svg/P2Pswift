import SwiftUI
import UniformTypeIdentifiers

class P2PManager: ObservableObject {
    private let serverURL = URL(string: "https://script.google.com/macros/s/AKfycbypAAOiGbEfOgDPXlNlnvOEkEjGzVIFbVDly5m5MKoCbbKQYiiKAlFjioVClQa3FfkP/exec")!
    
    @Published var statusText = "就绪"
    @Published var generatedCode = ""
    @Published var selectedFileName: String? = nil
    
    // 1. 上传验证码和文件信息
    func uploadSignal(peerInfo: String, completion: @escaping (String) -> Void) {
        let code = String(format: "%06d", Int.random(in: 0...999999))
        self.generatedCode = code
        self.statusText = "正在注册验证码（5分钟有效）..."
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "action": "upload",
            "code": code,
            "peerInfo": peerInfo
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    self.statusText = "上传失败"
                    return
                }
                self.statusText = "验证码已生成：[有效]"
                completion(code)
            }
        }.resume()
    }
    
    // 2. 检索验证码
    func searchSignal(code: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            self.statusText = "正在检索..."
        }
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "action": "search",
            "code": code
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { self.statusText = "网络错误" }
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    DispatchQueue.main.async {
                        if status == "found", let peerInfo = json["peerInfo"] as? String {
                            self.statusText = "连接成功！开始传输..."
                            completion(peerInfo)
                        } else if status == "expired" {
                            self.statusText = "验证码已超时（超过5分钟）或已失效"
                            completion(nil)
                        } else {
                            self.statusText = "未找到该验证码"
                            completion(nil)
                        }
                    }
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

struct P2PTransferView: View {
    @StateObject private var manager = P2PManager()
    @State private var inputCode = ""
    @State private var isSender = true
    @State private var showFileImporter = false // 控制文件选择弹窗
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("P2P DROP")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)
                    .padding(.top, 40)
                
                Picker("模式", selection: $isSender) {
                    Text("发送文件").tag(true)
                    Text("接收文件").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 40)
                
                Spacer()
                
                if isSender {
                    // --- 发送端 ---
                    VStack(spacing: 20) {
                        // 文件选择状态显示
                        Button(action: {
                            showFileImporter = true
                        }) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text(manager.selectedFileName ?? "点击选择要发送的文件")
                            }
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.green)
                            .padding()
                            .background(Color(.systemGray6).opacity(0.1))
                            .cornerRadius(10)
                        }
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
                            switch result {
                            case .success(let url):
                                manager.selectedFileName = url.lastPathComponent
                            case .failure(let error):
                                print(error.localizedDescription)
                            }
                        }
                        
                        Text(manager.generatedCode.isEmpty ? "----" : manager.generatedCode)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .tracking(8)
                        
                        Button(action: {
                            guard manager.selectedFileName != nil else {
                                manager.statusText = "请先选择文件！"
                                return
                            }
                            // 模拟网络信息
                            let mockPeerInfo = "192.168.3.50:9000"
                            manager.uploadSignal(peerInfo: mockPeerInfo) { code in
                                // 可以在这里开始监听连接
                            }
                        }) {
                            Text("生成 6 位验证码")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(width: 220, height: 50)
                                .background(Color.green)
                                .cornerRadius(25)
                        }
                    }
                } else {
                    // --- 接收端 ---
                    VStack(spacing: 20) {
                        TextField("输入 6 位验证码", text: $inputCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color(.systemGray6).opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            manager.searchSignal(code: inputCode) { peerInfo in
                                if let info = peerInfo {
                                    print("获取到对方地址: \(info)，准备下载")
                                }
                            }
                        }) {
                            Text("连接并接收")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(width: 220, height: 50)
                                .background(Color.green)
                                .cornerRadius(25)
                        }
                    }
                }
                
                Spacer()
                
                // 底部状态标签（显示 [有效]、[已失效] 或倒计时状态）
                Text(manager.statusText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.bottom, 30)
            }
        }
    }
}

