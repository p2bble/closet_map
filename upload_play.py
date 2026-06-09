"""
옷장지도 Play Store 자동 업로드 스크립트
사용법: python upload_play.py
"""

import os
import sys

PACKAGE_NAME = "com.p2bble.closet_map"
SERVICE_ACCOUNT_FILE = os.path.join(os.path.dirname(__file__), "service-account.json")
AAB_PATH = os.path.join(
    os.path.dirname(__file__),
    "build", "app", "outputs", "bundle", "release", "app-release.aab",
)
TRACK = "production"  # internal / alpha / beta / production


def main():
    # 파일 존재 확인
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        print(f"[오류] 서비스 계정 키 파일이 없어요: {SERVICE_ACCOUNT_FILE}")
        sys.exit(1)
    if not os.path.exists(AAB_PATH):
        print(f"[오류] AAB 파일이 없어요: {AAB_PATH}")
        print("먼저 'flutter build appbundle --release' 를 실행하세요.")
        sys.exit(1)

    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload
    except ImportError:
        print("[오류] 필요한 패키지가 없어요. 아래 명령어로 설치하세요:")
        print("  pip install google-api-python-client google-auth")
        sys.exit(1)

    print(f"서비스 계정: {SERVICE_ACCOUNT_FILE}")
    print(f"AAB: {AAB_PATH}  ({os.path.getsize(AAB_PATH) / 1024 / 1024:.1f} MB)")
    print(f"트랙: {TRACK}")
    print()

    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    service = build("androidpublisher", "v3", credentials=credentials)
    edits = service.edits()

    # Edit 세션 시작
    print("[1/4] Edit 세션 시작...")
    edit = edits.insert(body={}, packageName=PACKAGE_NAME).execute()
    edit_id = edit["id"]
    print(f"      edit_id: {edit_id}")

    # AAB 업로드
    print("[2/4] AAB 업로드 중...")
    media = MediaFileUpload(AAB_PATH, mimetype="application/octet-stream", resumable=True)
    bundle = edits.bundles().upload(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        media_body=media,
    ).execute()
    version_code = bundle["versionCode"]
    print(f"      버전 코드: {version_code}")

    # 트랙에 릴리즈 등록
    print(f"[3/4] '{TRACK}' 트랙에 릴리즈 등록...")
    edits.tracks().update(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        track=TRACK,
        body={
            "releases": [
                {
                    "versionCodes": [str(version_code)],
                    "status": "completed",
                }
            ]
        },
    ).execute()

    # 커밋
    print("[4/4] 커밋...")
    edits.commit(editId=edit_id, packageName=PACKAGE_NAME).execute()

    print()
    print(f"업로드 완료! 버전 코드 {version_code} → {TRACK} 트랙")


if __name__ == "__main__":
    main()
