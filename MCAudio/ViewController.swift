//
//  ViewController.swift
//  MCAudio
//
//  Created by Tewodros Wondimu on 10/29/22.
//

import UIKit
import AVFoundation
import MultipeerConnectivity
import DisPlayers_Audio_Visualizers

class ViewController: UIViewController {
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var streamButton: UIButton!
    @IBOutlet weak var stopStreamButton: UIButton!
    
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcAdvertiserAssistant: MCAdvertiserAssistant!
    var mcBrowserViewController: MCBrowserViewController!
    
    var ezRecorder: EZRecorder?
    var inputStream: InputStream!
    
    var streamAudioRequestInitiator: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // setup audio sessions
        audioSessionConfiguration()
        
        // setup multipeer connection
        setupMultipeerConnectivity()
    }
    
    // MARK: - circular buffer
    
    private static let MaxReadSize = 2048
    private static let BufferSize = MaxReadSize * 4
    
    private var availableReadBytesPtr = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    private var availableWriteBytesPtr = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    
    private var buffer =  UnsafeMutablePointer<TPCircularBuffer>.allocate(capacity: 1)
    
    private func writeStream() {
        let ptr = TPCircularBufferTail(buffer, availableWriteBytesPtr)
            
            // ensure we have non 0 bytes to write - which should always be true, but you may want to refactor things
            guard availableWriteBytesPtr.pointee > 0 else { return }
            
            let audioBuffer =  AudioBuffer(mNumberChannels: 1,
                                           mDataByteSize: UInt32(availableWriteBytesPtr.pointee),
                                           mData: ptr)
            let audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
            let audioBufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            audioBufferListPointer.pointee = audioBufferList
            
            self.ezRecorder?.appendData(from: audioBufferListPointer,
                                        withBufferSize: UInt32(availableWriteBytesPtr.pointee))
            
            TPCircularBufferConsume(buffer, availableWriteBytesPtr.pointee)
    }
    
    deinit {
      EZAudioUtilities.freeCircularBuffer(buffer)
      buffer.deallocate()
      availableReadBytesPtr.deallocate()
      availableWriteBytesPtr.deallocate()
      self.ezRecorder?.closeAudioFile()
      self.ezRecorder = nil
    }
    
    @IBAction func connectButtonTapped(_ sender: UIButton) {
            browseForPeers()
    }
    
    @IBAction func streamButtonTapped(_ sender: UIButton) {
        self.sendStartStreamingMicAudio()
        self.stopStreamButton.isEnabled = true
        self.streamButton.isEnabled = false
        
    }
    
    @IBAction func stopStreamButtonTapped(_ sender: UIButton) {
        self.sendStopStreamingMicAudio()
        self.streamButton.isEnabled = true
        self.stopStreamButton.isEnabled = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "MicSegue" {
            let micViewController = segue.destination as! MicViewController
            micViewController.mcSession = self.mcSession
            micViewController.peerID = self.peerID
            
            // if the peer sending the request to start streaming audio is known
            if self.streamAudioRequestInitiator != nil {
                // send the ViewController the requestor's peer id displayname
                micViewController.streamRequestingPeerID = self.streamAudioRequestInitiator
            }
        }
    }
    
}

extension ViewController {
    /**
            Setsup an audio session with play and record and makes it active
     */
    func audioSessionConfiguration() {
        // get the shared instance of AVAudioSession
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // set the category to play and record and make it active
            try audioSession.setCategory(.playAndRecord)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func setupMultipeerConnectivity() {
        peerID = MCPeerID(displayName: UIDevice.current.name)
        if self.mcSession == nil {
            self.mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        }
        self.mcSession.delegate = self
        
        // begin advertising
        advertiseToPeers()
    }
    
    
    func browseForPeers() {
        self.stopAdvertisingToPeers()
        
        self.mcBrowserViewController = MCBrowserViewController(serviceType: "bonjour", session: self.mcSession)
        self.mcBrowserViewController.delegate = self
        self.present(self.mcBrowserViewController, animated: true) {
            print("MC Browser presented")
        }
    }
    
    func advertiseToPeers() {
        if self.mcAdvertiserAssistant == nil {
            self.mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "bonjour", discoveryInfo: nil, session: self.mcSession)
        }
        self.mcAdvertiserAssistant.start()
        print("Started advertising")
    }
    
    func stopAdvertisingToPeers() {
        self.mcAdvertiserAssistant.stop()
        print("Stopped advertising")
    }
    
    func sendStartStreamingMicAudio() {
        if mcSession.connectedPeers.count > 0 {
            print("The connected peers are \(mcSession.connectedPeers) ")
            do {
                let startStreamingAudioAction = Action(actionToTake: .startStreamingAudio, time: nil, peer: self.peerID.displayName)
                guard let data = startStreamingAudioAction.getData() else { return }
                try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Not connected to any devices")
        }
    }
    
    func sendStopStreamingMicAudio() {
        if mcSession.connectedPeers.count > 0 {
            do {
                let stopStreamingAudioAction = Action(actionToTake: .stopStreamingAudio, time: nil, peer: self.peerID.displayName)
                guard let data = stopStreamingAudioAction.getData() else { return }
                try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Not connected to any devices")
        }
    }
}

extension ViewController: MCSessionDelegate, MCBrowserViewControllerDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
            case .notConnected:
                print("\(peerID.displayName) changed session state to not connected.")
            case .connecting:
                print("\(peerID.displayName) changed session state to connecting.")

            case .connected:
                print("\(peerID.displayName) changed session state to connected.")
            default:
                break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("didReceive data")
        
        // Create an action with the data that was received
        guard let action = Action.getObject(fromData: data) else { return }
        
        switch action.actionToTake {
            // if it is a start streaming audio data action, then present the
            // AudioViewController
            case .startStreamingAudio:
                DispatchQueue.main.async {
                    // if the device requesting to stream audio is known
                    if action.peer != nil {
                        // set a view controller property to be used in prepareSegue
                        self.streamAudioRequestInitiator = action.peer
                    }
                    self.performSegue(withIdentifier: "MicSegue", sender: self)
                }
            // if it is a start capturing audio stream action
            case .startCapturingAudioStream:
                DispatchQueue.main.async {
                    // get the action data
                    guard let data = action.data else { return }
                    
                    // create an AudioBasicStreamDescription object from data
                    guard let cASBD = CodableAudioStreamBasicDescription.getObject(fromData: data) else { return }
                    let asbd = cASBD.getASBD()
                    
                    // pass it to the recordAudio function to initialize the recorder
                    self.recordAudio(withASBD: asbd)
                }
            case .stopCapturingAudioStream:
                DispatchQueue.main.async {
                    self.stopStreamButton.sendActions(for: .touchUpInside)
                }
            default:
                break
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("didReceive stream from \(peerID.displayName) and name \(streamName)")
        DispatchQueue.main.async {
            self.inputStream = stream
            self.inputStream.delegate = self
            self.inputStream.schedule(in: .current, forMode: .default)
            self.inputStream.open()
            guard let error = self.inputStream.streamError else { return }
            print(error.localizedDescription)
        }
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("didStartReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("didFinishReceivingResourceWithName")
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        // dismiss the browser view
        browserViewController.dismiss(animated: true) {
            // if there are no connected peers after browsing
            if self.mcSession.connectedPeers.count <= 0 {
                self.advertiseToPeers()
            }
        }
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true) {
            // if there are no connected peers after browsing
            if self.mcSession.connectedPeers.count <= 0 {
                self.advertiseToPeers()
            }
        }
    }
}


// MARK: - Stream Delegate Methods
extension ViewController: StreamDelegate {
    // gets the input stream and the event code
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
         case .hasBytesAvailable:
           // if the input stream has bytes available
           // return the actual number of bytes placed in the buffer;
           guard let ptr = TPCircularBufferHead(buffer, availableReadBytesPtr) else {
             print("couldn't get buffer ptr")
             break;
           }
           let bytedsToRead = min(Int(availableReadBytesPtr.pointee), ViewController.MaxReadSize)
           let mutablePtr = ptr.bindMemory(to: UInt8.self, capacity: Int(bytedsToRead))
           let bytesRead = self.inputStream.read(mutablePtr,
                                                 maxLength: bytedsToRead) 
           if bytesRead < 0 {
             //Stream error occured
               print("what is going on here?")
               print(self.inputStream.streamError!.localizedDescription )
             break
           } else if bytesRead == 0 {
             //EOF
             break
           }
           
           TPCircularBufferProduce(buffer, Int32(bytesRead))
           
           DispatchQueue.main.async { [weak self] in
             self?.writeStream()
           }
         case .endEncountered:
           print("endEncountered")
           if self.inputStream != nil {
             self.inputStream.delegate = nil
             self.inputStream.remove(from: .current, forMode: .default)
             self.inputStream.close()
             self.inputStream = nil
           }
         case .errorOccurred:
           print("errorOccurred")
         case .hasSpaceAvailable:
           print("hasSpaceAvailable")
         case .openCompleted:
           print("openCompleted")
         default:
           break
         }
    }
    
    func recordAudio(withASBD asbd: AudioStreamBasicDescription) {
        // stores audio to temporary folder

        let audioOutputPath = NSTemporaryDirectory() + "audioOutput.aiff"
        let audioOutputURL = URL(fileURLWithPath: audioOutputPath)
//        let audioStreamBasicDescription = AudioStreamBasicDescription(mSampleRate: 44100.0, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 1081729024)
        self.ezRecorder = EZRecorder.init(url: audioOutputURL,
                                          clientFormat: asbd,
                                              fileType: .AIFF)
        
    }
    
    func stopRecording() {
        // stops the recorder
        if self.ezRecorder != nil {
            self.ezRecorder?.closeAudioFile()
            self.ezRecorder = nil
        }
    }
    

}
