import trackingTest from './Tracking.test'
import authTest from './Auth.test'
import audioDBTest from './AudioDB.test'
import mineQuestionPolicyTest from './MineQuestionPolicy.test'
import profilePolicyTest from './ProfilePolicy.test'
import questionListPolicyTest from './QuestionListPolicy.test'

export default function testsuite() {
  trackingTest()
  authTest()
  audioDBTest()
  mineQuestionPolicyTest()
  profilePolicyTest()
  questionListPolicyTest()
}
