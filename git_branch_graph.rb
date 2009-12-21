
require 'grit'
include Grit
repo = Repo.new(ARGV.first || ".")

def get_branches_by_sha(repo)
  branches = repo.branches + repo.remotes
  shas = {}
  branches.each do |branch|
    sha = branch.commit.sha
    next if sha == "ref:"
    shas[sha] ||= []
    shas[sha] << branch
  end
  shas
end

def get_parents(repo, shas)
  ENV["GIT_DIR"] = repo.path
  tree = {}
  shas.each do |sha, branches|
    commits = %x(git log --pretty='format:%H' #{sha}).split
    parents = []
    shas.each do |other_sha, other_branches|
      next if other_sha == sha
      #other_commits = repo.git.rev_list({}, other_sha).split
      if commits.include?(other_sha)
        parents << other_branches
      end
    end
    origin = branches.map { |b| b.name }.join("\n").inspect
    dest = parents.map { |other_branches| other_branches.map { |b| b.name }.join("\n").inspect }
    tree[origin] = dest
  end
  tree
end

def remove_grand_parents(tree)
  tree.each do |branch, parents|
    grand_parents = []
    parents.each do |parent|
      grand_parents += tree[parent]
    end
    grand_parents.each do |grand_parent|
      parents.delete grand_parent
    end
  end
end

shas = get_branches_by_sha(repo)
tree = get_parents(repo, shas)
remove_grand_parents(tree)

puts "digraph git {"
puts "  node [colorscheme=paired4 color=1 style=filled]"
puts "  edge [colorscheme=paired4 color=2]"
tree.each do |branch, parents|
  current = (branch == repo.head.name.inspect)
  if current
    puts "#{branch} [color=3]"
  end
  puts "  #{branch} -> { #{parents.join " "} }" + (current ? " [color=4]" : "")
end
puts "}"
