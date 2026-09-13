import trackingTest from './Tracking.test'
import authTest from './Auth.test'
import audioDBTest from './AudioDB.test'
import audioRecordingTest from './AudioRecording.test'
import mineQuestionPolicyTest from './MineQuestionPolicy.test'
import profilePolicyTest from './ProfilePolicy.test'
import questionListPolicyTest from './QuestionListPolicy.test'
import studyTimePolicyTest from './StudyTimePolicy.test'

export default function testsuite() {
  trackingTest()
  authTest()
  audioDBTest()
  audioRecordingTest()
  mineQuestionPolicyTest()
  profilePolicyTest()
  questionListPolicyTest()
  studyTimePolicyTest()
}
