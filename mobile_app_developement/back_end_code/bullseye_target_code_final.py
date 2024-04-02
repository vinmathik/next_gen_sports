import asyncio
import websockets
import cv2
import base64
import mediapipe as mp
import numpy as np
import os
import datetime
import ffmpeg
import pyaudio
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:postgres@localhost:5432/multistreaming'
db = SQLAlchemy(app)

class Cameraangle1(db.Model):
    __tablename__ = "cameraangle1"
    camera_id = db.Column(db.Integer, primary_key=True)
    camera_url = db.Column(db.String(255), nullable=False)
    min_angle = db.Column(db.Integer, nullable=False)
    max_angle = db.Column(db.Integer, nullable=False)
    view = db.Column(db.String(50), nullable=False)
    

def get_camera_urls():
    with app.app_context():
        cameras = Cameraangle1.query.all()
        return [(camera.camera_id, camera.camera_url, camera.min_angle, camera.max_angle, camera.view) for camera in cameras]

@app.route('/api/add_camera', methods=['POST'])
def add_camera():
    data = request.json
    try:
        camera_url = data['camera_url']
        min_angle = data['min_angle']
        max_angle = data['max_angle']
        view = data['view']
        new_camera = Cameraangle1(camera_url=camera_url, min_angle=min_angle, max_angle=max_angle, view=view)
        db.session.add(new_camera)
        db.session.commit()
     

        return jsonify({"message": "Camera added successfully"}), 201
    except KeyError as e:
        return jsonify({"error": f"Missing key in request data: {e}"}), 400
    except Exception as e:
        return jsonify({"error": f"Failed to add camera: {e}"}), 500

async def transmit(websocket, camera_data, camera_index, min_angle, max_angle):
    try:
        camera_id, camera_url, _, _, _ = camera_data 
        cap = cv2.VideoCapture(camera_url)
        
        if not cap.isOpened():
            raise ValueError(f"Error opening camera: {camera_url}")

        
        await websocket.send(f"Connection Established with Camera {camera_url}")

    
       
        output_folder = os.path.join('compressed_video', f'camera_{camera_index}_videos')
        os.makedirs(output_folder, exist_ok=True)
        current_time = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
       
        output_video_filename = f'camera_{camera_index}_video_{current_time}.avi'
        output_video_path = os.path.join(output_folder, output_video_filename)
        # print("@@@@@@",output_video_path)
        fourcc = cv2.VideoWriter_fourcc(*'MJPG')
        # print("@@@@",fourcc)
        out = cv2.VideoWriter(output_video_path, fourcc, 10.0, (640, 480))
        # print("@@@@@@",out)

        mp_pose = mp.solutions.pose
        # print("@@@@@@@@@@@",mp_pose)
        mp_drawing = mp.solutions.drawing_utils
        # print("@@@@@@@@",mp_drawing)
        pose = mp_pose.Pose(static_image_mode=False, min_detection_confidence=0.5, min_tracking_confidence=0.5)
        # print("@@@@@",pose)


        p = pyaudio.PyAudio()
        # print("@@@@@",p)
        stream = p.open(format=pyaudio.paInt16, channels=1, rate=44100, input=True, frames_per_buffer=1024)
        # print("@@@",stream)
        sound_frames = []
        # print("@@@",sound_frames)

        recording = False
        # print("@@@@",recording)
        buffer = []   
        # print("@@@@@",buffer)
        buffer_duration = 10   
        # print("@@@@@@",buffer_duration)
        sound_threshold = 0.5 
        print("@@@@@@",sound_threshold)
        # print(sound_threshold) 

        frame_count = 0   

        while cap.isOpened():
            # print("The cap is opened")
            success, frame = cap.read()
            # print("@@@@@@@@@@@@@@@@@@@@@@@@@@@")
            if not success:
                # print("@@@@@@@@@@@@@@@@@@@@")
                break
            # print("###################3")

            frame_count += 1
            # print("@@@@@@@@@@@@@@",frame_count)

            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            # print("@@@@@@@@",frame_rgb)
            results = pose.process(frame_rgb)
            # print("The results are",results)


            if results.pose_landmarks:
                # print("The landmarks are pose landmarks")
                landmarks = results.pose_landmarks.landmark
                # print("The landmarks is",landmarks)

                if landmarks[mp_pose.PoseLandmark.RIGHT_WRIST] and landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER]:
                    # print("#####################################")
                    right_wrist_landmark = landmarks[mp_pose.PoseLandmark.RIGHT_WRIST]
                    # print("@@@@@@@@@@@@@@@@@@@@@",right_wrist_landmark)
                    # print("The right wrist landmark is",right_wrist_landmark)
                    right_shoulder_landmark = landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER]
                    # print("The right shoulder landmark is",right_shoulder_landmark)

                    shooting_rifle_angle = np.arctan2(right_wrist_landmark.y - right_shoulder_landmark.y,
                                                     right_wrist_landmark.x - right_shoulder_landmark.x)
                    # print("@@@@#@@",shooting_rifle_angle)

                    if min_angle <= np.degrees(shooting_rifle_angle) <= max_angle:
                        # print("$$$$$$$$$$$$$")
                        if not recording:
                            # print("#####################")
                            recording = True
                            # print("@@@@@@@@@@@@@@@@@@@@@@@@@@@",recording)
                            start_recording_frame = frame_count
                            # print("Start recording frame",start_recording_frame)
                            current_time = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
                            # print("@@@@@",current_time)
                            video_filename = os.path.join(output_folder, f"shooting_{current_time}_camera_{camera_index}.avi")
                            # print("@@@@@",video_filename)
                            fourcc = cv2.VideoWriter_fourcc(*'XVID')
                            # print("@@@@@",fourcc)
                            pose_writer = cv2.VideoWriter(video_filename, fourcc, 10.0, (640, 480), isColor=True)
                            # print("@@@@@",pose_writer)

                        mp_drawing.draw_landmarks(frame, results.pose_landmarks, mp_pose.POSE_CONNECTIONS,
                                                  landmark_drawing_spec=mp_drawing.DrawingSpec(color=(0, 255, 0),
                                                                                                thickness=2,
                                                                                                circle_radius=2))
                        # print("the mp drawing land marks are the drawing landmarks")
                        cv2.putText(frame, "Correct", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                        # print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@2")
                    else:
                        mp_drawing.draw_landmarks(frame, results.pose_landmarks, mp_pose.POSE_CONNECTIONS,
                                                  landmark_drawing_spec=mp_drawing.DrawingSpec(color=(0, 0, 255),
                                                                                                thickness=2,
                                                                                                circle_radius=2))
                        # print("#################################################3")
                        cv2.putText(frame, "Wrong", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                        # print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@")

                    if recording:
                        # print("Recording is :")
                        pose_writer.write(frame)

            compressed_frame = cv2.resize(frame, (640, 480))
            # print("The compressed frame is",compressed_frame)
            out.write(compressed_frame)
            ret, buffer = cv2.imencode('.jpg', compressed_frame)
            # print("@@@@@@",ret,buffer)
            if not ret:
                print("It will not return ")
                break
                
            frame_bytes = buffer.tobytes()
            # print("@@@@@@@",frame_bytes)
            await websocket.send(base64.b64encode(frame_bytes).decode())
            if recording and frame_count - start_recording_frame >= buffer_duration * 10:
                # print("the recording and framecount are")
                recording = False
                # print("The recording are",recording)
                pose_writer.release()
                # print("The pose writer are released")

            sound_data = stream.read(1024)
            # print("The sound data are",sound_data)
     
            sound_frames.append(sound_data)
            # print("sound frames to append")

            if len(sound_frames) >= 10 * buffer_duration:
                # print("The sound frames are buffer durations")
                sound_frames.pop(0)
                # print("@@@@@@@@@@@@@@@@@@@@@@@@@@@")
                await asyncio.sleep(0.015)

        cap.release()
        # print("the cap release")
        out.release()
        # print("The out release")

        ffmpeg.input(output_video_path).output(output_video_path.replace(".avi", "_compressed.mp4"), vf='scale=640:480', b='1M').run()
        # print("@@@@@@@@@@@@@@@")

    except websockets.exceptions.ConnectionClosed as e:
        # print(f"Client Disconnected from Camera {camera_url}!")
        cap.release()
    except Exception as e:
        print(f"Error: {e}")

def detect_sound(sound_frames, sound_threshold):
    audio_data = b''.join(sound_frames)
    # print("@@@@@",audio_data)
    audio_amplitude = np.frombuffer(audio_data, dtype=np.int16)
    # print("@@@@@",audio_amplitude)
    sound_volume = np.max(audio_amplitude) / 32767.0
    # print("@@@@@",sound_volume)
    return sound_volume > sound_threshold

async def server(websocket, path):
    try:
        camera_urls = get_camera_urls()
        # print("@@@@@@@",camera_urls)
        camera_index = int(path.lstrip('/') or '0')
        # print("@@@@@@@",camera_index)

        if 0 <= camera_index < len(camera_urls):
            _, _, min_angle, max_angle, _ = camera_urls[camera_index]
            # print(f"Min Angle: {min_angle}, Max Angle: {max_angle}")
            await transmit(websocket, camera_urls[camera_index], camera_index, min_angle, max_angle)
        else:
            raise ValueError(f"Unsupported camera index: {camera_index}")
    except ValueError as e:
        print(f"Error: {e}")
    
if __name__ == "__main__":
    start_server = websockets.serve(server, host="192.168.29.151", port=5000)
    print("the start server is ",start_server)

    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()
