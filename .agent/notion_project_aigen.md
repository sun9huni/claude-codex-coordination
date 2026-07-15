**AIGEN-Fold · 프로젝트 허브**
<span color="gray">VAV1 분자글루 분해제 모델링 · 결론 먼저, 근거는 리포트로 · 갱신 {{DATE}}</span>
<columns>
	<column>
		<callout color="gray_bg">
			**지금 한 줄**
			- 구조 배치·생성은 가능하나 productive(촉매) 기하는 드물어 MD·실험이 판정하는 영역이다.
			- 정적·rigid 단일 척도는 진짜 기하를 반복 과벌점한다. 유연성이 결과를 가르는 변수.
			- 지금까지의 productive 양성은 비활성 대조로 끊기 전까지 조건부.
		</callout>
	</column>
	<column>
		<callout color="gray_bg">
			**다음 판단**
			- 비활성 글루 near-attack 대조 (productive 신호 검증, 최우선)
			- aigen-fold-core: DDB1 4체인 co-input
			- mmgbsa: Stage 2 (full-traj 샘플링 수정 후 게이트)
		</callout>
	</column>
</columns>
---
# 리포트
<callout color="gray_bg">
	**먼저 읽기**
	<mention-page url="https://www.notion.so/3951e76c3b608184864cf0a1da9e639c">통합 요약 (2026-06-16~07-06)</mention-page> · 구조 정확도 → 잠재 랭킹 두 레인 전체. pairwise loss로 cross-scaffold 0.383→0.558, 9NFR 실험구조로 파이프라인 재현(~2.9A) 검증까지.
</callout>
개별 리포트 (2026-06-16 ~ 07-06):
- <mention-page url="https://www.notion.so/3881e76c3b6081d58438f52b65d94409">CRL Integrative Metadynamics (7207)</mention-page> · K810 near-attack 정성 YES, FES 미수렴
- <mention-page url="https://www.notion.so/3881e76c3b6081dea2c1fc3917e33a18">Glue-MD Discriminator (8098)</mention-page> · 정적 스크린 FAIL → MD 완주, T6 판독 대기
- <mention-page url="https://www.notion.so/3881e76c3b60811798d7ca514c2b5a7a">Chirality Workstream</mention-page> · bypass 버그 수정, ring pucker ~10×
- <mention-page url="https://www.notion.so/3881e76c3b608126bafefde55092d795">MD-Interface Injection (8210)</mention-page> · #12 정적 주입은 lever 아님, productive=MD 레이어
- <mention-page url="https://www.notion.so/3881e76c3b6081519a2cf633190c9f9b">Assembly-Closure (CRLClosurePotential)</mention-page> · cone 과결정 엔진, 단일-접촉 시험
- <mention-page url="https://www.notion.so/38a1e76c3b6081f5853ee95bde127601">143-compound MD as-run</mention-page> · metad + MMGBSA 실행 세팅
- <mention-page url="https://www.notion.so/38a1e76c3b6081308c09d14cd973f8fa">5개 워크스트림 통합 요약 (06-16~25)</mention-page> · 구조·MD 레인 통합
- <mention-page url="https://www.notion.so/3941e76c3b608108b714dc3f6fa0ca38">Boltz-2 latent 잠재 랭킹 (07-02~05)</mention-page> · v2 does-structure-add / encoder / v1 확정, cross 0.383
- <mention-page url="https://www.notion.so/3951e76c3b6081af813cca97c63f4fc0">구조 표현 예측 + 9NFR 검증 (07-06)</mention-page> · trunk z vs pose-cond, 실험 재현 2.9A
전체 리포트 (라이브):
<database url="https://app.notion.com/p/36d1e76c3b6081eba9b1c08a40ac3412" inline="true" data-source-url="collection://94d8277f-bf77-4bc4-8acc-8b37701b830b"></database>
---
# 슬라이스
라이브 상태는 <mention-page url="https://www.notion.so/28d1e76c3b608069a83beab69a131a99">홈</mention-page> 보드 참조.
{{SLICES}}
---
# 결정 · 산출물
<database url="https://app.notion.com/p/36d1e76c3b60811687dce4132c36daa2" inline="true" data-source-url="collection://b11ae976-472b-46dd-98d9-b42ebe2e8b7b"></database>
<database url="https://app.notion.com/p/36d1e76c3b6081c7b935deeff1826a4e" inline="true" data-source-url="collection://2e47ef6d-0511-44c7-a55f-a9eb5bfe864f"></database>
