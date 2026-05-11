require "../spec_helper"

describe "Unigram integration tests" do
  it "test_sample" do
    lattice = Tokens::Models::Unigram::Lattice.new("ABC", 0, 2)
    lattice.insert(0, 1, 1.0, 3) # A
    lattice.insert(1, 1, 1.2, 4) # B
    lattice.insert(2, 1, 1.5, 5) # C
    lattice.insert(0, 2, 1.6, 6) # AB
    lattice.insert(1, 2, 1.7, 7) # BC
    lattice.insert(0, 3, 1.8, 8) # ABC

    thetas = [0.0, 0.01, 0.5, 0.7, 1.0]

    thetas.each do |theta|
      probs = {} of String => Float64
      probs["A B C"] = Math.exp(theta * (1.0 + 1.2 + 1.5))
      probs["AB C"] = Math.exp(theta * (1.6 + 1.5))
      probs["A BC"] = Math.exp(theta * (1.0 + 1.7))
      probs["ABC"] = Math.exp(theta * (1.8))

      # Normalize
      z = probs.values.sum
      probs.each { |k, v| probs[k] = v / z }

      n_trials = 10_000
      freq = {} of String => Int32
      n_trials.times do
        sampled = lattice.sample_token(theta).join(" ")
        freq[sampled] = (freq[sampled]? || 0) + 1
      end

      freq.size.should eq(probs.size)
      probs.each do |s, p|
        empirical = freq[s].to_f64 / n_trials.to_f64
        (empirical - p).abs.should be < 0.03
      end
    end
  end
end
