use ExtUtils::MakeMaker;

&WriteMakefile(
               NAME          => 'RTF::Tokenizer',
               DISTNAME      => 'RTF-Tokenizer',
               VERSION_FROM  => 'lib/RTF/Tokenizer.pm', 
	       PREREQ_PM     => { 
			'Test::More' => '0.01'
		 	}               
);
