//
//  MicrophoneViewController.swift
//  MCAudio
//
//  Created by Tewodros Wondimu on 10/29/22.
//

import UIKit

import AVFAudio
import DisPlayers_Audio_Visualizers
import MultipeerConnectivity

class MicViewController: UIViewController {
    
    var mcSession: MCSession!
    var peerID: MCPeerID!
    var streamRequestingPeerID: String?
    var outputStream: OutputStream!
    
    var ezMicrophone: EZMicrophone?
    var ezRecorder: EZRecorder?

    @IBOutlet weak var stopStreamingButton: UIButton!
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sendMicrophoneAudioDescription()
        setupStreaming()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        captureAudio()
        self.mcSession.delegate = self
    }
    
    @IBAction func stopStreamingButtonTapped(_ sender: UIButton) {
        stopCapturingMicrophoneAudio()
        self.dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destinationViewController = segue.destination as! ViewController
        destinationViewController.mcSession = self.mcSession
    }
}

// MARK: - Multipeer Connectivity Delegate
extension MicViewController: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // if the connection state changes stop the audio capture and recording and dismiss the view
        switch state {
            case .notConnected:
                DispatchQueue.main.async {
                    self.stopStreamingButton.sendActions(for: .touchUpInside)
                }
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
        // create an Action object with the data that was received
        guard let action = Action.getObject(fromData: data) else { return }
        
        switch action.actionToTake {
            // if the action is to stop streaming audio, stop capturing
            // microphone audio and stop recording the audio to file
            case .stopStreamingAudio:
                stopCapturingMicrophoneAudio()
            
                // dismiss the audio view controller
                DispatchQueue.main.async {
                    self.dismiss(animated: true) {
                        print("dismissed micViewcontroller")
                    }
                }
            default:
                break
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("didReceive stream")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("didStartReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("didFinishReceivingResourceWithName")
    }
}

extension MicViewController {
    
    func captureAudio() {
        // starts capturing audio from the mic
        if self.ezMicrophone == nil {
            self.ezMicrophone = EZMicrophone.init(microphoneDelegate: self)
        }
        self.ezMicrophone?.startFetchingAudio()
    }
    
    /**
        Sends an unreliable message containing the ASBD of the devices microphone to other
        devices that are recording video
     */
    func sendMicrophoneAudioDescription() {
        // check if there are any connected peers
        if self.mcSession.connectedPeers.count > 0 {
            do {
                // check that the microphone is available
                guard self.ezMicrophone != nil else { return }
                
                // get a codable version of AudioStreamBasicDescription
                let audioStreamBasicDescription = CodableAudioStreamBasicDescription(withASBD: self.ezMicrophone!.audioStreamBasicDescription())
                guard let casbdData = audioStreamBasicDescription.getData() else { return }
                
                // create an action and send the data as part of the action
                let action = Action(actionToTake: .startCapturingAudioStream, time: nil, data: casbdData)
                guard let data = action.getData() else { return }
                
                // send the microphone ASBD to all peers recording video
                try self.mcSession.send(data, toPeers: self.mcSession.connectedPeers, with: .unreliable)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    /**
        Setup audio streaming to other devices by opening an OutputStream
     */
    func setupStreaming() {
        // check if there are any connected users
        if self.mcSession.connectedPeers.count > 0 {
            let requestingPeerID: MCPeerID!
            
            requestingPeerID = self.mcSession.connectedPeers[0]
            do {
                // stream the audio buffer list to the receiver
                self.outputStream = try mcSession.startStream(withName: "spare mic stream", toPeer: requestingPeerID)
                
                // open the output stream to start streaming data
                self.outputStream.open()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func stopCapturingMicrophoneAudio() {
        // stops the microphone capture
        if self.ezMicrophone != nil {
            self.ezMicrophone?.stopFetchingAudio()
        }
    }
    
    /**
        Sends a message to the Camera View Controller of all connected peers to stop
        capturing audio
     */
    func sendStopCapturingVideo() {
        // check if there are any connected peers
        if mcSession.connectedPeers.count > 0 {
            
            do {
                // create a stop capturing video action and get the JSON data
                let stopCapturingVideoAction = Action(actionToTake: .stopCapturingAudioStream, time: nil)
                guard let data = stopCapturingVideoAction.getData() else { return }
                
                // send the Action JSON data to other devices that are
                // currently capturing video
                try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Not connected to any devices")
        }
    }
}


// MARK: - EZAudio's EZMicrophone Delegate Methods
extension MicViewController: EZMicrophoneDelegate {
    /**
        Delegate method of EZAudio's EZMicrophone class, that is used to update the equalizer
        in real time
     */
    func microphone(_ microphone: EZMicrophone!, hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!, withBufferSize bufferSize: UInt32, withNumberOfChannels numberOfChannels: UInt32) {

    }
    
    /**
        Delegate method of EZAudio's EZMicrophone class, that is used to save the microphone audio
        to the
     */
    func microphone(_ microphone: EZMicrophone!, hasBufferList bufferList: UnsafeMutablePointer<AudioBufferList>!, withBufferSize bufferSize: UInt32, withNumberOfChannels numberOfChannels: UInt32) {
        /// Send microphone audio through the output stream
        // get the audio buffer list from the pointer
        let audioBufferList = bufferList.pointee
        // gets the audio buffer from the audio buffer list
        // which is only one because there is one channel
        let audioBuffer = audioBufferList.mBuffers

        // get the pointer to a buffer of audio data using .mData which is an UnsafeMutableRawPointer?
        // then change it to UInt8 so it can be put on the output stream
        guard let data = audioBuffer.mData?.assumingMemoryBound(to: UInt8.self) else { return }
        if self.outputStream == nil {
            self.setupStreaming()
        }
        // if the output stream has space available
        if self.outputStream.hasSpaceAvailable {
            // write out the UnsafeMutablePointer<UInt8> data to the outputstream
            self.outputStream.write(data, maxLength: Int(audioBuffer.mDataByteSize))
        }
    }
}
