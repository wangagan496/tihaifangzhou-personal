import audioDBTest from './AudioDB.test'
import authServerTest from './AuthServer.test'

export default function testsuite() {
  audioDBTest()
  authServerTest()
}
