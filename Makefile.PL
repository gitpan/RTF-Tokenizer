use ExtUtils::MakeMaker;
 
&WriteMakefile(
           NAME           => 'RTF::Tokenizer',
           EXE_FILES      => [ 'eg/rtfdiff', 'eg/rtfdump' ],
           DISTNAME       => 'RTF-Tokenizer',
           VERSION_FROM   => 'lib/RTF/Tokenizer.pm', 
           PREREQ_PM      => { 
             'Test::More' => '0.01'
           }               
);
