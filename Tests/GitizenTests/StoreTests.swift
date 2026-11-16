import Foundation
import Testing
@testable import Gitizen

@Suite struct ParseRepoTests {
    @Test(arguments: [
        ("openziti/ziti", "openziti/ziti"),
        ("  openziti/ziti\n", "openziti/ziti"),
        ("https://github.com/openziti/ziti", "openziti/ziti"),
        ("https://www.github.com/openziti/ziti/", "openziti/ziti"),
        ("github.com/openziti/ziti/pulls?q=is%3Aopen", "openziti/ziti"),
        ("git@github.com:openziti/ziti.git", nil),
        ("https://github.com/openziti/ziti.git", "openziti/ziti"),
        ("openziti/zrok.dev", "openziti/zrok.dev"),
        ("openziti", nil),
        ("", nil),
        ("../etc", nil),
        ("owner/..", nil),
        ("own er/repo", nil),
    ] as [(String, String?)])
    func parse(input: String, expected: String?) {
        #expect(Store.parseRepo(input) == expected)
    }
}

@Suite struct RepoStateTests {
    private func issue(_ number: Int, pr: Bool = false) -> IssueDTO {
        IssueDTO(
            number: number, title: "t\(number)",
            htmlUrl: URL(string: "https://github.com/o/r/issues/\(number)")!,
            pullRequest: pr ? .init() : nil)
    }

    @Test func picksUpOnlyNewerItems() {
        var state = RepoState(seenNumber: 10, seenStars: 5, stars: 5)
        state.update(stars: 7, openIssues: [issue(12, pr: true), issue(11), issue(10), issue(3)])
        #expect(state.new.map(\.number) == [12, 11])
        #expect(state.new.map(\.isPR) == [true, false])
        #expect(state.newStars == 2)
        #expect(state.newCount == 4)
    }

    @Test func dropsItemsThatAreNoLongerOpen() {
        var state = RepoState(seenNumber: 10, seenStars: 0, stars: 0)
        state.update(stars: 0, openIssues: [issue(13), issue(12), issue(11)])
        state.update(stars: 0, openIssues: [issue(14), issue(12)])
        #expect(state.new.map(\.number) == [14, 12])
    }

    @Test func markSeenResetsBaseline() {
        var state = RepoState(seenNumber: 10, seenStars: 0, stars: 0)
        state.update(stars: 3, openIssues: [issue(12), issue(11)])
        state.markSeen()
        #expect(state.newCount == 0)
        #expect(state.seenNumber == 12)
        state.update(stars: 3, openIssues: [issue(12), issue(11)])
        #expect(state.newCount == 0)
    }

    @Test func unstarsDoNotMaskLaterStars() {
        var state = RepoState(seenNumber: 0, seenStars: 10, stars: 10)
        state.update(stars: 8, openIssues: [])
        #expect(state.newStars == 0)
        state.update(stars: 9, openIssues: [])
        #expect(state.newStars == 1)
    }
}
