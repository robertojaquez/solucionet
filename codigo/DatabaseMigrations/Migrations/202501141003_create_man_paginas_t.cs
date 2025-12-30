using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141003)]
	public class _202501141003_create_man_paginas_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_paginas_t.sql");
		}

		public override void Down()
		{
		}
	}
}
