#!/usr/bin/env ruby
# Grab courses-clean.json from search-and-compare-data repo
# Run './generate.rb'
require 'json'

file = File.read('courses-clean.json')
data = JSON.parse(file)
provider = 'The Yorkshire Rose Teaching Alliance'
next_cycle = false
courses = data.select {|c| c['provider'] == provider }

all_accredited_bodies = data.map {|c| c['accrediting'] }.uniq.compact.sort

# https://stackoverflow.com/questions/164979/uk-postcode-regex-comprehensive
postcodeRegex =  /([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})/

data = {
  'rolled-over': false,
  'next-cycle': next_cycle,
  'multi-organisation': false,
  'ucas-gt12': 'Applicants must confirm their place',
  'ucas-alerts': 'Get an email for each application you receive',
  'training-provider-name': provider,
  'provider-code': courses.first['providerCode'],
  'ucas-postal-address-building-and-street': '1 Fake street name',
  'ucas-postal-address-organisation-town-or-city': 'Town name',
  'ucas-postal-address-county': 'London',
  'ucas-postal-address-postcode': 'LB1 1AA',
  'ucas-admin-name': 'Joe Admin',
  'ucas-admin-email': 'admin@myorg.ac.uk',
  'ucas-admin-telephone': '01234 321456'
}

def course_qualification(c)
  if c['subjects'].map {|s| s.downcase.capitalize }.include?('Further education')
    return 'PGCE'
  end

  if !c['qualifications'] || c['qualifications'].length == 0
    qual = "Unknown"
  else
    qual = (c['qualifications'].include?('Postgraduate') || c['qualifications'].include?('Professional')) ? 'PGCE with QTS' : 'QTS'
  end

  qual
end

# Map course data for the `imported from UCAS` view
data['courses'] = courses.each_with_index.map do |c, idx|
  options = []
  courseCode = c['programmeCode']
  lorem = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

  if idx < 7
    data[courseCode + '-about-this-course'] = lorem
    data[courseCode + '-interview-process'] = lorem
    data[courseCode + '-placement-school-policy'] = lorem
    data[courseCode + '-duration'] = '1 year'
    data[courseCode + '-salary-details'] = lorem
    data[courseCode + '-fee'] = '9,000'
    data[courseCode + '-fee-international'] = '14,000'
    data[courseCode + '-fee-details'] = lorem
    data[courseCode + '-financial-support'] = lorem
    data[courseCode + '-qualifications-required'] = lorem
    data[courseCode + '-personal-qualities'] = lorem
    data[courseCode + '-other-requirements'] = lorem
  end

  if next_cycle
    data[courseCode + '-publish-state'] = 'rolled-over'
  else
    if idx == 0 || idx == 4 || idx == 5
      data[courseCode + '-publish-state'] = 'published'
      data[courseCode + '-published-before'] = true
    end

    if idx == 1 || idx == 2
      data[courseCode + '-publish-state'] = 'draft'
      data[courseCode + '-published-before'] = false
    end

    if idx == 3
      data[courseCode + '-fee'] = '10,000'
      data[courseCode + '-publish-state'] = 'published-with-changes'
      data[courseCode + '-published-before'] = true
    end

    if idx == 3
      data[courseCode + '-publish-state'] = 'withdrawn'
      data[courseCode + '-published-before'] = true
      data[courseCode + '-withdraw-reason'] = 'It was published by mistake'
    end
  end

  qual = course_qualification(c)

  partTime = c['campuses'].map {|g| g['partTime'] }.uniq.reject {|r| r == "n/a"}.count > 0
  fullTime = c['campuses'].map {|g| g['fullTime'] }.uniq.reject {|r| r == "n/a"}.count > 0
  salaried = c['route'] == "School Direct training programme (salaried)" ? ' with salary' : ''

  if fullTime && partTime
    options << "#{qual}, full time or part time#{salaried}"
    fullPart = 'Full time or part time'
  elsif partTime
    options << "#{qual} part time#{salaried}"
    fullPart = 'Part time'
  else
    options << "#{qual} full time#{salaried}"
    fullPart = 'Full time'
  end

  schools = c['campuses'].map { |a| { name: a['name'], address: a['address'], code: a['code'] == '' ? '-' : a['code'] } }

  subjects = c['subjects'].map {|s| s.downcase.capitalize }

  sen = subjects.include?('Special educational needs')
  if subjects.include?('Primary')
    level = 'Primary'
  elsif subjects.include?('Further education')
    level = 'Further education'
  elsif subjects.include?('Secondary')
    level = 'Secondary'
  else
    level = 'Further education'
  end

  rejectedSubjects = [
    'Primary',
    'Secondary',
    'Further education',
    'Special educational needs',
    'Science'
  ]

  languageSubjects = [
    'French',
    'Spanish',
    'German',
    'Italian',
    'Japanese',
    'Mandarin',
    'Russian',
    'Urdu',
    'Languages',
    'Languages (asian)',
    'Languages (european)',
    'Modern languages',
    'Modern languages (other)'
  ]

  rejectedLanguageSubjects = [
    'Languages',
    'Languages (asian)',
    'Languages (european)'
  ]

  subjectsWithoutLevel = subjects - rejectedSubjects

  if subjectsWithoutLevel.length == 0
    subject = level
  elsif !(subjectsWithoutLevel & languageSubjects).empty?
    subject = 'Modern languages'
    languages = subjectsWithoutLevel - rejectedLanguageSubjects
    data[courseCode + '-languages'] = languages
  else
    subject = subjects[0]
  end

  type = c['route'] == "School Direct training programme (salaried)" ? 'Salaried' : 'Fee paying (no salary)'
  minRequirements = [
    'Mathematics',
    'English'
  ]

  if level == 'Further education'
    data[courseCode + '-outcome'] = 'PGCE only (without QTS)'
  else
    data[courseCode + '-outcome'] = qual
  end

  data[courseCode + '-no-qualifications-yet'] = 'Yes (recommended)'
  data[courseCode + '-equivalency-test'] = 'Yes (recommended)'
  data[courseCode + '-equivalency-subjects'] = level == 'Primary' ? ['English', 'Mathematics', 'Science'] : ['English', 'Mathematics']
  data[courseCode + '-generated-title'] = c['name']
  data[courseCode + '-change-title'] = 'Yes, that’s correct'
  #data[courseCode + '-title'] = c['name']
  data[courseCode + '-applications-open'] = '10 October 2018'
  data[courseCode + '-who-apply-type'] = "Option A"
  data[courseCode + '-type'] = type
  data[courseCode + '-languages'] = languages
  data[courseCode + '-phase'] = level
  data[courseCode + '-min-requirements'] = minRequirements
  data[courseCode + '-subject'] = subject
  data[courseCode + '-full-part'] = fullPart
  data[courseCode + '-locations'] = schools.map { |s| s[:name] }
  data[courseCode + '-sen'] = 'This is a SEND course' if sen
  data[courseCode + '-has-accredited-body'] = c['accrediting'] ? 'Another organisation' : 'We are the accredited body'
  data[courseCode + '-accredited-body'] = c['accrediting'] || provider
  data[courseCode + '-vacancies-flag'] = idx == 4 ? 'No' : 'Yes'
  data[courseCode + '-vacancies-choice'] = idx == 4 ? 'There are no vacancies' : 'There are some vacancies'
  data[courseCode + '-full-time-and-part-time'] = partTime && fullTime
  data[courseCode + '-multi-location'] = c['campuses'].length > 1
  data[courseCode + '-start-date'] = 'September 2019'

  c['campuses'].each_with_index do |campus, i|
    data["#{courseCode}-vacancies-#{i + 1}"] = 'Vacancies'
  end

  {
    level: level,
    sen: sen,
    accrediting: c['accrediting'] || provider,
    languages: languages,
    subjects: subjectsWithoutLevel,
    subject: subject,
    outcome: qual,
    starts: 'September 2019',
    type: type,
    name: c['name'],
    route: c['route'],
    providerCode: c['providerCode'],
    programmeCode: courseCode,
    schools: schools,
    options: options,
    minRequirements: minRequirements,
    'full-part': fullPart
  }
end

data['courses'].sort_by! { |k| k[:name] }

# Find all schools across all courses and flatten into array of schools
data['schools'] = courses.map { |c| c['campuses'].map { |a| { name: a['name'], address: a['address'], code: a['code'] == '' ? '-' : a['code'] } } }.flatten.uniq
data['schools'].sort_by! { |k| k[:name] }

data['schools'].each do |school|
  school[:urn] = 100000
  postcodeMatched = postcodeRegex.match(school[:address])

  school[:postcode] = postcodeMatched ? postcodeMatched[0] : ''
  data["#{school[:code]}-location-picked"] = "#{school[:name]} (#{school[:urn]}, City, #{school[:postcode]})"
  data["#{school[:code]}-location-type"] = "A school or university"
  data["#{school[:code]}-name"] = school[:name]
  data["#{school[:code]}-urn"] = school[:urn]
  data["#{school[:code]}-postcode"] = school[:postcode]
  data["#{school[:code]}-address"] = school[:address]
end

# Create a list of accreditors
data['accreditors'] = courses.uniq {|c| c['accrediting'] }.map  do |c|
  {
    name: c['accrediting'].nil? ? provider : c['accrediting']
  }
end

data['accreditors'].sort_by! { |k| k[:name] }
data['self_accrediting'] = (data['accreditors'].length == 1 && data['accreditors'][0][:name] == provider)

data['new-course'] = {
  'include-accredited': courses.first['route'].include?('School Direct'),
  'include-fee-or-salary': courses.first['route'].include?('School Direct'),
  'include-locations': data['schools'].length > 1
}

data['accredited-bodies-choices'] = all_accredited_bodies.map { |k| { name: k } }

# Output to prototype
File.open('lib/prototype_data.json', 'w') { |file| file.write(JSON.pretty_generate(data) + "\n") }
