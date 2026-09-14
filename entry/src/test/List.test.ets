import trackingTest from './Tracking.test'
import authTest from './Auth.test'
import audioDBTest from './AudioDB.test'
import audioRecordingTest from './AudioRecording.test'
import mineQuestionPolicyTest from './MineQuestionPolicy.test'
import profilePolicyTest from './ProfilePolicy.test'
import questionListPolicyTest from './QuestionListPolicy.test'
import studyTimePolicyTest from './StudyTimePolicy.test'
import interviewCatalogTest from './InterviewCatalog.test'
import diagnosticPolicyTest from './DiagnosticPolicy.test'
import transcriptionPolicyTest from './TranscriptionPolicy.test'
import studyIntegrationTest from './StudyIntegration.test'
import scoreSettingsPolicyTest from './ScoreSettingsPolicy.test'
import messageReminderPolicyTest from './MessageReminderPolicy.test'

export default function testsuite() {
  trackingTest()
  authTest()
  audioDBTest()
  audioRecordingTest()
  mineQuestionPolicyTest()
  profilePolicyTest()
  questionListPolicyTest()
  studyTimePolicyTest()
  interviewCatalogTest()
  diagnosticPolicyTest()
  transcriptionPolicyTest()
  studyIntegrationTest()
  scoreSettingsPolicyTest()
  messageReminderPolicyTest()
}
