import interviewCatalogTest from './InterviewCatalog.test'
import suite0 from './Auth.test'
import suite1 from './MineQuestionPolicy.test'
import suite2 from './QuestionListPolicy.test'
import suite3 from './StudyTimePolicy.test'
import suite4 from './Tracking.test'

export default function testsuite() {
  suite0()
  suite1()
  suite2()
  suite3()
  suite4()
  interviewCatalogTest()
}
